import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

function manualCopy(result) {
  const dialog = document.createElement("dialog");
  dialog.className = "topic-discussion-exporter-dialog";
  const heading = document.createElement("h2");
  heading.textContent = i18n("topic_discussion_exporter.preview");
  const content = document.createElement("div");
  content.className = "topic-discussion-exporter-content";
  content.contentEditable = "true";
  content.innerHTML = result.html;
  const copyButton = document.createElement("button");
  copyButton.textContent = i18n("topic_discussion_exporter.copy_rich");
  const closeButton = document.createElement("button");
  closeButton.textContent = i18n("topic_discussion_exporter.close");
  copyButton.addEventListener("click", () => {
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(content);
    selection.removeAllRanges();
    selection.addRange(range);
    let wroteClipboard = false;
    const writeCleanHtml = (event) => {
      if (!event.clipboardData) {
        return;
      }
      event.clipboardData.setData("text/html", result.html);
      event.clipboardData.setData("text/plain", result.text);
      event.preventDefault();
      wroteClipboard = true;
    };
    document.addEventListener("copy", writeCleanHtml, true);
    const copied = document.execCommand("copy");
    document.removeEventListener("copy", writeCleanHtml, true);
    selection.removeAllRanges();
    if (copied && wroteClipboard) {
      dialog.close();
    } else {
      window.alert(i18n("topic_discussion_exporter.select_manual"));
      content.focus();
    }
  });
  closeButton.addEventListener("click", () => dialog.close());
  dialog.addEventListener("close", () => dialog.remove(), { once: true });
  dialog.append(heading, content, copyButton, closeButton);
  document.body.appendChild(dialog);
  dialog.showModal();
}

function copyTopic(topicId) {
  const request = ajax(`/topic-discussion-exporter/topics/${topicId}.json`);
  const html = request.then((result) => new Blob([result.html], { type: "text/html" }));
  const plain = request.then((result) => new Blob([result.text], { type: "text/plain" }));

  if (navigator.clipboard?.write && window.ClipboardItem) {
    const item = new ClipboardItem({ "text/html": html, "text/plain": plain });
    navigator.clipboard.write([item]).then(
      () => window.alert(i18n("topic_discussion_exporter.copied")),
      async () => {
        try {
          manualCopy(await request);
        } catch {
          window.alert(i18n("topic_discussion_exporter.failed"));
        }
      }
    );
  } else {
    request.then(manualCopy, () => window.alert(i18n("topic_discussion_exporter.failed")));
  }
}

export default apiInitializer((api) => {
  api.registerTopicFooterButton({
    id: "copy-topic-discussion-rich",
    icon: "copy",
    translatedLabel: i18n("topic_discussion_exporter.copy"),
    translatedTitle: i18n("topic_discussion_exporter.copy"),
    displayed() {
      return this.currentUser?.admin === true && !this.topic?.isPrivateMessage;
    },
    action() {
      copyTopic(this.topic.id);
    },
    dropdown() {
      return this.site.mobileView;
    },
  });

  api.addTopicAdminMenuButton((topic) => {
    if (!api.getCurrentUser()?.admin || topic.isPrivateMessage) {
      return;
    }
    return {
      icon: "copy",
      translatedLabel: i18n("topic_discussion_exporter.copy"),
      action: () => copyTopic(topic.id),
    };
  });
});
