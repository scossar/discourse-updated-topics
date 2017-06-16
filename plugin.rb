# name: discourse-updated-topics
# version: 0.1

PLUGIN_NAME = 'discourse_updated_topics'.freeze

after_initialize do

  module ::DiscourseUpdatedTopics
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseUpdatedTopics
    end
  end

  require_dependency 'application_controller'
  class DiscourseUpdatedTopics::UpdatedTopicsController < ::ApplicationController

    def comment_numbers
      since = params[:sync_period].to_i.days
      time_range = (Time.now - since)..Time.now
      topics_data = Topic.joins(:topic_embed)
                        .where(updated_at: time_range)
                        .pluck(:id, :title, :posts_count)
                        .map {|t| {id: t[0], title: t[1], comment_count: t[2] - 1}}

      render json: topics_data
    end
  end

  DiscourseUpdatedTopics::Engine.routes.draw do
    get 'comment-numbers/:sync_period' => 'updated_topics#comment_numbers', constraints: {sync_period: /\d+/}
  end

  Discourse::Application.routes.append do
    mount ::DiscourseUpdatedTopics::Engine, at: 'discourse-updated-topics'
  end
end