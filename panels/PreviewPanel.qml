import QtQuick
import qs.Commons
import qs.Ui
import "../shared"
import "../logic"
import "../state"
import "../shared/Utils.js" as Utils

// Preview panel (Space). Eleventh component extracted from
// core -- purely read-only (no clicks of its own beyond
// "don't let the tap pass through to what's behind"), so unlike
// Sidebar.qml it doesn't even need a signal: everything that used to be
// calls to root.isImage(root.previewEntry)/etc. repeated several
// times across the file are now already-resolved booleans passed by the
// parent (which is still the only one that sees those functions).
Item {
  id: root

  property bool open: false
  property string entryName: ""
  property bool hasEntry: false
  property bool isImageEntry: false
  property bool isVideoEntry: false
  property bool isTextEntry: false
  property bool isPdfEntry: false
  property bool isAudioEntry: false
  property url imageSource: ""
  property url videoThumbSource: ""
  property string highlightedText: ""
  property string plainText: ""
  property url pdfImageSource: ""
  property var audioInfo: []
  property string fallbackSizeText: ""
  // Non-empty when the cursor is on a directory: preview its contents, the
  // way yazi's third column does, instead of showing "no file selected".
  property string dirPath: ""
  property Item fileMeta: null
  // Fraction the file list takes of the area this panel splits with it.
  // Defaults to the ACTIVE pane's global; BackgroundPanel overrides it with
  // the yazi ratio so a background pane's split doesn't depend on whatever
  // stance the active pane happens to be in.
  property real listFraction: NavState.listFraction

  BorderSurface {
    id: previewPanel
    visible: root.open
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: parent.width * (1 - root.listFraction) - Style.spacing.rowGap
    radius: Style.cornerRadius
    color: Color.menu.selectedBackground
    borderSpec: Border.flat(Color.menu.border, Style.normalBorderWidth)
    padding: Style.spacing.sm

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: previewCol
      anchors.fill: parent
      anchors.topMargin: previewPanel.contentTopInset
      anchors.rightMargin: previewPanel.contentRightInset
      anchors.bottomMargin: previewPanel.contentBottomInset
      anchors.leftMargin: previewPanel.contentLeftInset
      spacing: Style.spacing.sm

      Text {
        id: previewTitle
        width: parent.width
        text: root.entryName
        font.pixelSize: Style.font.title
        font.family: Style.font.family
        font.bold: true
        color: Color.menu.text
        elide: Text.ElideMiddle
      }

      PanelSeparator { id: previewSep; foreground: Color.menu.text; strength: 0.15 }

      Image {
        visible: root.isImageEntry
        width: parent.width
        height: parent.height - 60
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        source: root.isImageEntry ? root.imageSource : ""
      }

      Image {
        visible: root.isVideoEntry
        width: parent.width
        height: parent.height - 60
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        source: root.isVideoEntry ? root.videoThumbSource : ""
      }

      Flickable {
        visible: root.isTextEntry
        width: parent.width
        height: parent.height - 60
        clip: true
        contentWidth: width
        contentHeight: (root.highlightedText.length > 0 ? previewHighlightedItem : previewTextItem).implicitHeight

        // Syntax highlighting when native SyntaxHighlighter recognized the language.
        // Same Flickable/position as the plain Text below,
        // one of the two is always hidden.
        Text {
          id: previewHighlightedItem
          visible: root.highlightedText.length > 0
          width: parent.width
          textFormat: Text.RichText
          text: root.highlightedText
          font.pixelSize: Style.font.subtitle
          font.family: "monospace"
          color: Color.menu.text
          wrapMode: Text.Wrap
        }

        Text {
          id: previewTextItem
          visible: root.highlightedText.length === 0
          width: parent.width
          text: root.plainText || "(empty)"
          font.pixelSize: Style.font.subtitle
          font.family: "monospace"
          color: Color.menu.text
          wrapMode: Text.Wrap
        }
      }

      Image {
        visible: root.isPdfEntry
        width: parent.width
        height: parent.height - 60
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        source: root.isPdfEntry ? root.pdfImageSource : ""
      }

      Column {
        visible: root.isAudioEntry && root.audioInfo.length > 0
        width: parent.width
        spacing: Style.spacing.sm

        Repeater {
          model: root.audioInfo

          Row {
            required property var modelData
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              // 84 didn't reach "Sample rate" (it stuck to
              // the value without a space, confirmed by measuring the
              // font's real glyph) -- 120 leaves plenty of margin
              // for any current label of this
              // table at the app's real font size.
              width: 120
              text: parent.modelData.label
              font.pixelSize: Style.font.subtitle
              font.family: Style.font.family
              color: Color.menu.text
              opacity: Style.emphasis.secondary
            }

            Text {
              width: parent.width - 120 - Style.spacing.sm
              text: parent.modelData.value
              font.pixelSize: Style.font.subtitle
              font.family: Style.font.family
              color: Color.menu.text
              elide: Text.ElideRight
            }
          }
        }
      }

      Column {
        visible: root.dirPath === ""
          && root.hasEntry && !root.isImageEntry && !root.isTextEntry
          && !(root.isVideoEntry && root.videoThumbSource !== "")
          && !(root.isPdfEntry && root.pdfImageSource !== "")
          && !(root.isAudioEntry && root.audioInfo.length > 0)
        width: parent.width
        spacing: Style.spacing.sm

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          // Text does NOT clip to its width -- without a wrapMode a line
          // longer than the panel painted straight across the neighboring
          // columns.
          wrapMode: Text.Wrap
          text: "No preview available"
          font.pixelSize: Style.font.title
          font.family: Style.font.family
          color: Color.menu.text
          opacity: Style.emphasis.muted
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          text: "Press Enter to open with default app"
          font.pixelSize: Style.font.subtitle
          font.family: Style.font.family
          color: Color.menu.text
          opacity: Style.emphasis.secondary
        }
      }

    }

    // OUTSIDE the Column on purpose. EmptyState positions itself with
    // anchors.centerIn, and an anchored child inside a positioner doesn't
    // just misplace itself -- the Column logs "Column will not function" and
    // PERMANENTLY stops laying out its children. Once "No file selected" had
    // been shown once, every later text preview rendered its Flickable at
    // y:0, painting the file's first line on top of the filename header.
    EmptyState {
      visible: !root.hasEntry && root.dirPath === ""
      centerOn: previewCol
      message: "No file selected"
      subMessage: "Select a file to preview its contents"
    }

    // Directory under the cursor -> its listing (yazi's third column).
    // Deliberately a SIBLING of the content Column, not a child: as a child
    // it rendered its first row straight on top of the filename header, no
    // matter how its height was expressed. Anchoring under the header is
    // explicit and cannot be relaid out from under us.
    Item {
      visible: root.dirPath !== ""
      clip: true
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.top: parent.top
      anchors.topMargin: previewPanel.contentTopInset + previewTitle.height
        + previewSep.height + Style.spacing.sm * 2
      anchors.leftMargin: previewPanel.contentLeftInset
      anchors.rightMargin: previewPanel.contentRightInset
      anchors.bottomMargin: previewPanel.contentBottomInset

      DirLister {
        id: dirPreviewLister
        showHidden: NavState.showHidden
      }

      Connections {
        target: root
        function onDirPathChanged() { if (root.dirPath !== "") dirPreviewLister.list(root.dirPath) }
      }
      // A panel created WITH a dirPath (a background pane restoring its
      // saved preview) never gets the change signal -- list once at birth.
      Component.onCompleted: if (root.dirPath !== "") dirPreviewLister.list(root.dirPath)

      ListView {
        id: dirPreviewList
        anchors.fill: parent
        model: dirPreviewLister.entries
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
          id: dirPreviewRow
          required property var modelData
          width: dirPreviewList.width
          height: dirRowVisual.implicitHeight
            + (NavState.compactMode ? Style.spacing.xs : Style.spacing.md) * 2

          // Deliberately does NOT request folder counts. FolderCountState
          // marks a path pending and never clears it, so a path whose request
          // does not land is permanently un-requestable — by anyone. This
          // column re-lists on EVERY cursor move, so requesting here marked
          // paths faster than the counter could answer and poisoned the cache
          // for the main list, which silently lost its item counts. Cached
          // counts still show; folders you have not visited show age only.

          FileRowVisual {
            id: dirRowVisual
            anchors.fill: parent
            anchors.rightMargin: Style.spacing.controlGap
            name: dirPreviewRow.modelData.name || ""
            isDir: dirPreviewRow.modelData.type === "dir"
            isSymlink: dirPreviewRow.modelData.isSymlink === true
            compact: NavState.compactMode
            isBroken: dirPreviewRow.modelData.link === "broken"
            fileIconGlyph: Utils.iconFor(dirPreviewRow.modelData)
            metaText: root.fileMeta
              ? root.fileMeta.lineFor(dirPreviewRow.modelData, root.dirPath) : ""
          }
        }
      }

      EmptyState {
        visible: dirPreviewLister.entries.length === 0
        centerOn: parent
        message: "Empty folder"
        subMessage: ""
      }
    }

  }
}
