#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <atomic>
#include <memory>
#include <mutex>
#include <qqmlregistration.h>

// Native recursive search. Replacement for
// search-recursive.sh: walks `root` in depth, filters by substring
// (case-insensitive) over the file/folder NAME, skips
// hidden ones unless showHidden, and returns up to 201 entries with the same
// shape as DirectoryModel ({type,name,size,mtime,link}) -- `name` is the path
// RELATIVE to root, so the rest of the code (join with currentPath,
// rename, delete, open...) works the same as with the script.
//
// Async (QThreadPool) and cancelable: each search() opens a "generation"; a
// new search or cancel() invalidates the previous one (neither walks too much
// nor emits obsolete results). 201 are requested on purpose -- results() marks
// truncated=true if there were more than 200 and trims to 200, just like the
// script's contract (the QML side warns of an incomplete list).
//
// Instantiable (QML_ELEMENT, like DirectoryModel/ProcessRunner): SearchOps
// has its own instance. No dependency on Quickshell.
class SearchWorker : public QObject {
  Q_OBJECT
  QML_ELEMENT

public:
  explicit SearchWorker(QObject *parent = nullptr);
  ~SearchWorker() override;

  // Launches a recursive search by file/folder name under `root`.
  Q_INVOKABLE void search(const QString &root, const QString &query,
                          bool showHidden);

  // Launches a recursive content search INSIDE files under `root`.
  // Searches for text matches line by line (case-insensitive).
  // Skips binary files and files larger than 5 MB.
  Q_INVOKABLE void searchContent(const QString &root, const QString &query,
                                 bool showHidden);

  // Cancels the search in progress (invalidates its generation): no result
  // is emitted. Idempotent.
  Q_INVOKABLE void cancel();

signals:
  // Results of the last active search. `entries` are objects
  // {type,name,size,mtime,link}; `truncated` = there were more than 200 matches.
  void results(const QVariantList &entries, bool truncated);

private:
  // Life guard against the dangling `this` (same pattern as
  // DirectoryModel/FileOperations): a worker that finishes after the object is
  // destroyed must not deliver. The worker takes the lock and only invokes if
  // alive is still true; the destructor takes the same lock and sets it to
  // false, so they never coincide.
  //
  // `gen` lives HERE, not as a member of the object: the walk polls it on every
  // entry to honour cancellation, and a poll of a member would dereference an
  // already-destroyed SearchWorker (a tab closed mid-search). In the shared
  // control block it outlives the object and the worker never touches `this`
  // until the alive check has passed. search() increments and captures it; the
  // worker discards (does not emit) if it stopped being the active one --
  // covers both cancel() and a search that supersedes another.
  struct Life {
    std::mutex mtx;
    bool alive = true;
    std::atomic<quint64> gen{0};
  };
  std::shared_ptr<Life> m_life = std::make_shared<Life>();
};
