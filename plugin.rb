# name: discourse-updated-topics
# version: 0.1

# The basic outline for a Discourse WordPress plugin. Feel free to rename anything.
# The request from WordPress is passing the Discourse api_key and api_username in
# the request. Adding some kind of error response would be useful.

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

    # Returns Discourse Topic data for topics that have been updated between a
    # given start time and the current time. The embed_url is used on WordPress
    # to match a Topic to a WordPress post. Ideally, the WordPress post_id would
    # be saved on Discourse and returned with this data. If the WordPress post_id
    # is added as a property to the Discourse topic, the plugin will still need to
    # return the embed_url so that it can be used with Topics that were created
    # before the property was added to Discourse Topics. Possibly, a 'legacy' option
    # could be added to the plugin, so that when the plugin is used on new Discourse/WordPress
    # installations, the join to the TopicEmbed table could be left out.
    def comment_numbers
      since = params[:sync_period].to_i.minutes
      time_range = (Time.current - since)..Time.current
      topics_data = Topic.joins(:topic_embed)
                        .where(updated_at: time_range)
                        .pluck(:id, :title, :posts_count, :embed_url)
                        .map {|t| {id: t[0], title: t[1], comment_count: t[2] - 1, embed_url: t[3]}}

      render json: topics_data
    end
  end

  DiscourseUpdatedTopics::Engine.routes.draw do
    get 'comment-numbers/:sync_period' => 'updated_topics#comment_numbers'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseUpdatedTopics::Engine, at: 'discourse-updated-topics'
  end
end