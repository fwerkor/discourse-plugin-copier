# frozen_string_literal: true

module ::TopicDiscussionExporter
  class ExportsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_administrator

    def show
      topic = ::Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic

      guardian.ensure_can_see!(topic)
      raise Discourse::NotFound unless topic.archetype == Archetype.default

      posts =
        ::Post
          .where(
            topic_id: topic.id,
            post_type: ::Post.types[:regular],
            hidden: false,
            user_deleted: false,
            deleted_at: nil,
          )
          .includes(:user)
          .order(:post_number)

      render json: Renderer.new(topic, posts).call
    end

    private

    def ensure_administrator
      raise Discourse::InvalidAccess unless current_user&.admin?
    end
  end
end
