# Discourse Plugin Copier

An open-source Discourse plugin for copying **an entire topic**, including its replies, into a clean, editor-friendly rich-text article. Works with any rich-text editor that accepts HTML pasted from the clipboard.

## Features

- Administrator-only export action at the bottom of a topic and in the topic admin menu.
- Server-side export of **all visible regular posts**, in chronological order. It does not depend on posts loaded into the browser.
- Article structure: title, source URL, authors, UTC timestamps, post numbers and the complete conversation.
- Whitelisted text formatting: headings, paragraphs, lists, quotes, code, images, links and tables.
- Removes forum chrome, embeds, scripts, arbitrary inline styles, background colors and tracking-related presentation.
- Writes both `text/html` and `text/plain` to the clipboard (Clipboard API). If direct clipboard access is unavailable, opens a rich-text copy dialog.
- English and Simplified Chinese UI.
- No AIA-specific identifiers or hard-coded hosting paths.

## Requirements

Discourse with support for plugin `api-initializers` and the Topic Footer Button API. JavaScript clipboard rich-copy support works best on Chromium-based browsers over HTTPS.

## Installation (standard Docker-based Discourse)

In `/var/discourse/containers/app.yml`, under `hooks.after_code.exec`:

```yaml
- git clone https://github.com/fwerkor/discourse-plugin-copier.git discourse-topic-discussion-exporter
```

Run `cd /var/discourse && ./launcher rebuild app`. Alternatively, mount the plugin directory at `/var/www/discourse/plugins/discourse-topic-discussion-exporter` and rebuild. A running Discourse server must load the Ruby controller and build the frontend assets.

## Usage

Sign in as an **administrator**, open a regular topic and choose **Copy full discussion** at the bottom of the topic or under the topic admin menu. Paste into a rich-text editor. On browsers without permission to copy formatted content, use the copy button inside the fallback preview.

### Access and privacy

The server checks `current_user.admin?` **on every export request**, then applies Discourse's `guardian.ensure_can_see!` check. It excludes deleted, hidden, user-deleted, moderator-action, whisper and private-message posts. Non-admin accounts cannot request export data. Copied content is **not** automatically published anywhere; review consent and content before redistribution.

### Notes

HTML is intentionally restricted to styles and elements that tend to survive external rich-text editors. Third-party editor sanitizers may still modify the appearance or fail to import remote images. In that case upload pictures into your target editor separately.

Since v1.0.1, all text-containing blocks use explicit pixel font sizes and line heights (e.g. `font-size:16px;line-height:29px`) rather than unitless inherited line heights. This reduces differences after rich-text clipboard import and avoids inadvertent small line heights in editors that rewrite pasted CSS. The target publishing editor may still rewrite markup, so review its own structure-checker warnings after pasting.

## Development

Ruby renderer specs live under `spec/lib/topic_discussion_exporter`; run them inside a Discourse development/test installation with the plugin installed:

```sh
bundle exec rspec plugins/discourse-topic-discussion-exporter/spec/lib/topic_discussion_exporter/renderer_spec.rb
```

## License

MIT.
