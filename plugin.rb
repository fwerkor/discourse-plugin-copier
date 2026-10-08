# frozen_string_literal: true

# name: discourse-topic-discussion-exporter
# about: Administrator-only rich HTML export of complete Discourse topics.
# version: 1.0.4
# authors: fwerkor
# url: https://github.com/fwerkor/discourse-plugin-copier

register_asset "stylesheets/topic-discussion-exporter.scss"
module ::TopicDiscussionExporter
  PLUGIN_NAME = "discourse-topic-discussion-exporter"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace TopicDiscussionExporter
    config.autoload_paths << File.join(config.root, "lib")
  end
end

after_initialize do
  Discourse::Application.routes.append do
    mount ::TopicDiscussionExporter::Engine, at: "/topic-discussion-exporter"
  end
end
