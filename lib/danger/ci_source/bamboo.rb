# https://www.atlassian.com/software/bamboo
# https://support.atlassian.com/bamboo/
# https://confluence.atlassian.com/bamboo/bamboo-variables-289277087.html
require "danger/request_sources/bitbucket_cloud"
require "danger/request_sources/bitbucket_server"

module Danger
  # ### CI Setup
  # To get the pull request ID, you must add this script as a new Script task before your Build Job running Danger:
  # ```
  # git remote add bitbucket $bamboo_planRepository_repositoryUrl
  # COMMIT=$(git rev-parse HEAD)
  # BITBUCKETSERVER_PULL_REQUEST_ID=$(git ls-remote bitbucket | grep $COMMIT | grep "pull-requests" | sed "s/.*requests\/\(.*\)\/from/\1/g")
  # git remote remove bitbucket
  # echo "BITBUCKETSERVER_PULL_REQUEST_ID=$BITBUCKETSERVER_PULL_REQUEST_ID"
  # ```
  #
  # #### BitBucket Cloud
  #
  # You will need to add the following environment variables as build parameters or by exporting them inside your
  # Simple Command Runner.
  # - `DANGER_BITBUCKETCLOUD_USERNAME`
  # - `DANGER_BITBUCKETCLOUD_PASSWORD`
  # - `BITBUCKET_REPO_SLUG`
  #
  # #### BitBucket Server
  #
  # You will need to add the following environment variables as build parameters or by exporting them inside your
  # Simple Command Runner.
  # - `DANGER_BITBUCKETSERVER_USERNAME`
  # - `DANGER_BITBUCKETSERVER_PASSWORD`
  # - `DANGER_BITBUCKETSERVER_HOST`
  # - `BITBUCKETSERVER_REPO_SLUG`
  # - `BITBUCKETSERVER_PULL_REQUEST_ID` (optional)
  #
  class Bamboo < CI
    class << self
      def validates_as_bitbucket_pr?(env)
        # ["BITBUCKET_REPO_SLUG", "BITBUCKET_BRANCH_NAME", "BITBUCKET_REPO_URL"].all? { |x| env[x] && !env[x].empty? }
        ["BITBUCKET_REPO_SLUG"].all? { |x| env[x] && !env[x].empty? }
      end

      def validates_as_bitbucket_server_pr?(env)
        # ["BITBUCKETSERVER_REPO_SLUG", "BITBUCKETSERVER_PULL_REQUEST_ID", "BITBUCKETSERVER_REPO_URL"].all? { |x| env[x] && !env[x].empty? }
        ["BITBUCKETSERVER_REPO_SLUG"].all? { |x| env[x] && !env[x].empty? }
      end
    end

    def self.validates_as_ci?(env)
      env.key? "bamboo_buildKey"
    end

    def self.validates_as_pr?(env)
      validates_as_bitbucket_pr?(env) || validates_as_bitbucket_server_pr?(env)
    end

    def supported_request_sources
      @supported_request_sources ||= [
        Danger::RequestSources::BitbucketCloud,
        Danger::RequestSources::BitbucketServer
      ]
    end

    def initialize(env)
      # NB: Unfortunately Bamboo doesn't provide these variables
      # automatically so you have to add these variables manually to your
      # project or build configuration
      if self.class.validates_as_bitbucket_pr?(env)
        extract_bitbucket_variables!(env)
      elsif self.class.validates_as_bitbucket_server_pr?(env)
        extract_bitbucket_server_variables!(env)
      end
    end

    private

    def extract_bitbucket_variables!(env)
      self.repo_slug       = env["BITBUCKET_REPO_SLUG"]
      self.pull_request_id = bitbucket_pr_from_env(env)
      self.repo_url        = env["BITBUCKET_REPO_URL"]
    end

    def extract_bitbucket_server_variables!(env)
      self.repo_slug = env["BITBUCKETSERVER_REPO_SLUG"]
      self.pull_request_id = env["BITBUCKETSERVER_PULL_REQUEST_ID"].to_i || bitbucket_server_pr_from_env(env)
      self.repo_url = env["bamboo_planRepository_repositoryUrl"]
    end

    # This is a little hacky, because Bitbucket doesn't provide us a PR id
    def bitbucket_pr_from_env(env)
      branch_name = env["bamboo_planRepository_branch"]
      repo_slug   = env["BITBUCKET_REPO_SLUG"]
      begin
        Danger::RequestSources::BitbucketCloudAPI.new(repo_slug, nil, branch_name, env).pull_request_id
      rescue
        raise "Failed to find a pull request for branch \"#{branch_name}\" on Bitbucket."
      end
    end

    # This is a little hacky, because Bitbucket Server doesn't provide us a PR id
    def bitbucket_server_pr_from_env(env)
      branch_name   = env["bamboo_planRepository_branch"]
      repo_slug     = env["BITBUCKETSERVER_REPO_SLUG"]
      project, slug = repo_slug.split("/")
        Danger::RequestSources::BitbucketServerAPI.new(project, slug, nil, branch_name, env).pull_request_id
      rescue
        raise "Failed to find a pull request for branch \"#{branch_name}\" on Bitbucket Server."
      end
    end
  end
end
