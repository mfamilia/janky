module Janky
  module Builder
    class Client
      def initialize(url, callback_url)
        @url          = URI(url)
        @callback_url = URI(callback_url)
      end

      # The String absolute URL of the Jenkins server.
      attr_reader :url

      # The String absoulte URL callback of this Janky host.
      attr_reader :callback_url

      # Trigger a Jenkins build for the given Build.
      #
      # build - a Build object.
      #
      # Returns the Jenkins build URL.
      def run(build)
        unless skip_build build
          Runner.new(@url, build, adapter).run
        end
      end

      def skip_build(build)
        is_skip_active = ENV["JANKY_SKIP_ACTIVE"]
        if is_skip_active.nil? || is_skip_active.empty? || is_skip_active.downcase != "true"
          return false
        end

        skip_flag = ENV["JANKY_SKIP_FLAG"]
        if skip_flag.nil? || skip_flag.empty? || build.commit_message.nil? || build.commit_message.empty?
          return false
        end

        if build.commit_message.include? skip_flag
          message = "Going skip on #{build.repo_name}/#{build.branch_name}"
          Rails.logger.info "Sending skip message to chat service"
          ::Janky::ChatService.speak(message, build.room_id)
          Rails.logger.info "Skip Build flag found...skipping build."
          return true
        end
      end

      # Retrieve the output of the given Build.
      #
      # build - a Build object. Must have an url attribute.
      #
      # Returns the String build output.
      def output(build)
        Runner.new(@url, build, adapter).output
      end

      # Setup a job on the Jenkins server.
      #
      # name          - The desired job name as a String.
      # repo_uri      - The repository git URI as a String.
      # template_path - The Pathname to the XML config template.
      #
      # Returns nothing.
      def setup(name, repo_uri, template_path)
        job_creator.run(name, repo_uri, template_path)
      end

      # The adapter used to trigger builds. Defaults to HTTP, which hits the
      # Jenkins server configured by `setup`.
      def adapter
        @adapter ||= HTTP.new(url.user, url.password)
      end

      def job_creator
        @job_creator ||= JobCreator.new(url, @callback_url)
      end

      # Enable the mock adapter and make subsequent builds green.
      def green!
        @adapter = Mock.new(true, Janky.app)
        job_creator.enable_mock!
      end

      # Alias green! as enable_mock!
      alias_method :enable_mock!, :green!

      # Alias green! as reset!
      alias_method :reset!, :green!

      # Enable the mock adapter and make subsequent builds red.
      def red!
        @adapter = Mock.new(false, Janky.app)
      end

      # Simulate the first callback. Only available when mocked.
      def start!
        @adapter.start
      end

      # Simulate the last callback. Only available when mocked.
      def complete!
        @adapter.complete
      end
    end
  end
end
