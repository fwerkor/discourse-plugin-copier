# frozen_string_literal: true

TopicDiscussionExporter::Engine.routes.draw do
  get "/topics/:topic_id" => "exports#show", constraints: { topic_id: /[0-9]+/ }
end
