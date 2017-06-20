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
    # given start time and the current time.
    #
    # The Discourse api_key, api_username, and WordPress site_url are passed as query
    # params from WordPress.
    # The embed_url is used on WordPress to match a Topic to a WordPress post.
    # The site_url is used to match topics to WordPress subsites on multisite
    # Wordpress installations.
    # If connected to a WordPress multisite setup, this function could be called
    # as ofter as once every 10 minutes by each site on the network. Instead of
    # selecting topic_embeds that match the site_url in the topic_data query, I'm
    # removing them from the result of the query after it's been made. The reason
    # for doing it this way is so that the result of the topic_data query can be cached.

    def topic_data
      site_url = params[:site_url].present? ? CGI.unescape(params[:site_url]) : nil
      since = params[:sync_period].to_i.minutes
      time_range = (Time.current - since)..Time.current

      topics_data = Topic.joins(:topic_embed)
                        .where(updated_at: time_range)
                        .limit(30)
                        .pluck(:id, :title, :posts_count, :embed_url)
                        .map {|t| {id: t[0], title: t[1], comment_count: t[2] - 1, embed_url: t[3]}}

      # Possibly useful for dealing with WordPress multisite installations. I think it's
      # going to be possible to remove this.
      if site_url
        topics_data.delete_if do |data_set|
          !data_set[:embed_url].starts_with?(site_url + '/')
        end
      end

      render json: topics_data
    end

  end

  DiscourseUpdatedTopics::Engine.routes.draw do
    get 'topic-data/:sync_period' => 'updated_topics#topic_data', constraints: {sync_period: /\d+/, format: 'json'}
  end

  Discourse::Application.routes.append do
    mount ::DiscourseUpdatedTopics::Engine, at: 'discourse-updated-topics'
  end
end