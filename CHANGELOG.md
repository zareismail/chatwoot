# Changelog

Notable changes to the **ragham** fork. Upstream Chatwoot releases are not tracked here
— only what this fork adds or changes on top of them.

Dates are the day the work landed on `ragham`, newest first.

## Deploying

The widget and dashboard are served from the deployed image, so nothing below reaches
users — including the Android app, which loads the widget from the deployed host — until
it ships:

```bash
bash deploy/docker.sh
```

Then bump the tag on both the `app` and `sidekiq` pods, restart them, and run migrations
if the release includes any. Changes to the Android app are independent of this and need
their own APK build.

---

## 2026-08-09

Widget work driven by how the chat behaves inside the Android app. Several of the fixes
below span both repositories: the widget change alone is not enough, the app has to be
rebuilt too.

### Widget — added

- **Voice messages are confirmed before they send.** Stopping the recorder used to upload
  the take immediately, with no chance to hear it back or drop it. It now holds the
  recording in a preview with a player, a send button and a discard button, and nothing
  leaves the browser until send is tapped. Cancelling mid-recording still discards without
  ever reaching the preview.
- **Swipe between gallery attachments.** The image follows the touch and commits to the
  next or previous attachment past a threshold; shorter drags spring back. Swipes that
  start on a video or audio control scrub that control instead.
- **The gallery holds every attachment type.** It previously collected images only, so
  videos, voice messages and files could not be reached from it. Images keep rotation,
  video and audio get native controls, and anything else shows a named placeholder. The
  download button serves all of them.
- **Zoom controls in the gallery**, beside the rotation buttons, from 1× to 4× in 0.5
  steps. A zoomed image scrolls so its edges stay reachable, and swiping stands down while
  zoomed so a horizontal drag pans instead of changing attachment.

### Widget — fixed

- **Video attachments no longer render as a black box on Android.** Android Chromium
  treats `preload="metadata"` as container metadata only and never decodes a frame, where
  desktop Chrome paints the first one. The source now carries a `#t=0.001` media fragment,
  which turns the load into a seek and forces that frame to be decoded.

  This relies on the attachment host answering HTTP Range requests, and on the video being
  faststart (`moov` before `mdat`). A video with its metadata at the end will download in
  full before showing anything.

### Android app — fixed

Companion changes in `raghamapp/android`, branch `ismail/chatwoot-webview-downloads`. Each
is a web platform feature that a `WebView` does not implement unless the host application
opts in, which is why they failed only inside the app.

- **Attachment links do something again.** The widget opens attachments with
  `target="_blank"`, which Chromium discards unless the WebView supports multiple windows
  — the clicks never reached `shouldOverrideUrlLoading` or the download listener. Multiple
  windows are enabled and the new-window URL is routed to the downloader, or to an external
  viewer for anything that is not an attachment.
- **Downloaded files can be found.** Files were written into the app cache directory and
  only became reachable if a MediaStore copy succeeded — a copy that was skipped entirely
  below API 29 and swallowed its own exceptions above it, so "download finished" could
  appear with the file nowhere the user could browse to. Downloads now go through the
  platform `DownloadManager`, into the public Downloads folder, with a system notification
  that opens the file.
- **The video fullscreen button works.** Chromium delegates the Fullscreen API to
  `WebChromeClient.onShowCustomView`, whose default implementation does nothing. The player
  is now expanded over the root layout, and the activity declares `configChanges` so
  rotating no longer recreates it and reloads the widget mid-video.
- **Back closes what is on top.** Back used to close the whole chat from inside the image
  gallery and from fullscreen video. It now exits fullscreen first, then offers the press
  to the page, and only finishes the activity when nothing claims it.

---

## 2026-08-07

### Dashboard — changed

- **Conversations open on the unread list** when the account has any, instead of always
  landing on all conversations and leaving unread ones to be found. Only on the first
  navigation, so choosing all conversations from the sidebar afterwards still lands there.
- **The assignee tabs start on all** rather than mine, which had hidden every unassigned
  conversation behind an extra click. A custom role without permission for the all tab
  falls back to the first tab it does have.

### Backend — changed

- **A contact now has exactly one conversation.** The unique index on
  `conversations.contact_id` is enforced by migration in every environment, matching on the
  indexed column so a hand-made index is detected whatever it is named, and skipping the
  DDL when it is already unique. Production already carried it from a manual change.

  Every path that creates a conversation now looks up by contact across all inboxes rather
  than by contact inbox: the builder behind the dashboard and public API, the widget, each
  incoming channel service, campaigns, email threading and voice calls. Messaging a contact
  from the dashboard previously raised `RecordNotUnique`.

### Backend — removed

- **The inbox `lock_to_single_conversation` setting**, which only ever scoped to a contact
  inbox and is now subsumed by the rule above.
- **Instagram direct message and Twitter parent tweet grouping**, which a single
  conversation per contact cannot express.

---

## 2026-08-06

### Widget — added

- **A jump-to-latest pill.** A floating button appears over the conversation whenever the
  reader has scrolled up, showing the number of agent messages that arrived while they were
  reading, or a plain "jump to latest" when there are none. Tapping it returns to the
  newest message.

  Its count is the agent messages that arrived after the last one the reader saw. An
  earlier version derived it from the growth of the message list, which reported the
  history loaded on mount, and the older messages prepended while scrolling up, as new.

### Widget — fixed

- **The soft keyboard no longer springs up when a media player is tapped.** Native audio
  and video controls handle the tap entirely inside their shadow root, so nothing
  propagates out and the chat input keeps the focus it would lose on a tap anywhere else —
  which the Android WebView answers by raising the keyboard. Media events are the only
  signal a control was used, so focus is released from play, pause and seeking.

---

## 2026-08-04

### Dashboard — added

- **An Unanswered filter** in the sidebar, listing conversations where the customer sent
  the last message, an agent has already read it, and nobody replied. Private notes and
  activity messages are ignored, since an internal note is not an answer, and unread
  conversations stay in the unread list.

---

## 2026-08-03

### Widget — fixed

- **Reading is no longer interrupted by incoming messages.** An arriving agent message
  scrolled the conversation to the bottom regardless of where the reader was. It now
  auto-scrolls only when the reader is already near the bottom, when older messages are
  being prepended, or when the newest message is the reader's own — the jump-to-latest
  pill covers the rest.
