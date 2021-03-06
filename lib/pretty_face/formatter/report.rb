module PrettyFace
  module Formatter

    module Formatting
      def summary_percent(number, total)
        percent = (number.to_f / total) * 100
        "#{number} (#{'%.1f' % percent}%)"
      end

      def formatted_duration(duration)
        m, s = duration.divmod(60)
        "#{m}m#{'%.3f' % s}s"
      end

      def image_tag_for(status, source=nil)
        dir = "#{directory_prefix_for(source)}images"
        "<img src=\"#{dir}/#{status}.png\" alt=\"#{status}\" title=\"#{status}\" width=\"30\">"
      end

      def directory_prefix_for(source=nil)
        dir = ''
        back_dir = source.count('/') if source
        back_dir.times do
          dir += '../'
        end
        dir
      end
    end


    class Report
      attr_reader :features

      def initialize
        @features = []
      end

      def current_feature
        @features.last
      end

      def current_scenario
        current_feature.scenarios.last
      end

      def add_feature(feature)
        @features << feature
      end

      def add_scenario(scenario)
        current_feature.scenarios << scenario
      end

      def begin_background
        @processing_background = true
      end

      def end_background
        @processing_background = false
      end

      def processing_background_steps?
        @processing_background
      end

      def add_step(step)
        current_scenario.steps << step
      end
    end

    class ReportFeature
      include Formatting
      attr_accessor :scenarios, :background, :description
      attr_reader :title, :file, :start_time, :duration, :parent_filename

      def initialize(feature, parent_filename)
        @scenarios = []
        @background = []
        @start_time = Time.now
        @description = feature.description
        @parent_filename = parent_filename
      end

      def close(feature)
        @title = feature.title
        @duration = Time.now - start_time
        a_file = feature.file.sub(/\.feature/, '.html')
        to_cut = a_file.split('/').first
        @file = a_file.sub("#{to_cut}/", '')
      end

      def steps
        steps = []
        scenarios.each { |scenario| steps += scenario.steps }
        steps
      end

      def background_title
        title = @background.find { |step| step.keyword.nil? }
      end

      def background_steps
        @background.find_all { |step| step.keyword }
      end

      def scenarios_for(status)
        scenarios.find_all { |scenario| scenario.status == status }
      end

      def scenario_summary_for(status)
        scenarios_with_status = scenarios_for(status)
        summary_percent(scenarios_with_status.length, scenarios.length)
      end

      def step_summary_for(status)
        steps_with_status = steps.find_all { |step| step.status == status }
        summary_percent(steps_with_status.length, steps.length)
      end

      def scenario_average_duration
        durations = scenarios.collect { |scenario| scenario.duration }
        formatted_duration(durations.reduce(:+).to_f / durations.size)
      end

      def step_average_duration
        steps = scenarios.collect { |scenario| scenario.steps }
        durations = steps.flatten.collect { |step| step.duration }
        formatted_duration(durations.reduce(:+).to_f / durations.size)
      end

      def get_binding
        binding
      end

      def description?
        !description.nil?  && !description.empty?
      end

      def has_background?
        background.length > 0
      end
    end

    class ReportScenario
      attr_accessor :name, :file_colon_line, :status, :steps, :duration, :image, :image_label, :image_id

      def initialize(scenario)
        @steps = []
        @start = Time.now
      end

      def populate(scenario)
        @duration = Time.now - @start
        if scenario.instance_of? Cucumber::Ast::Scenario
          @name = scenario.name
          @file_colon_line = scenario.file_colon_line
        elsif scenario.instance_of? Cucumber::Ast::OutlineTable::ExampleRow
          @name = scenario.scenario_outline.name
          @file_colon_line = scenario.backtrace_line
        end
        @status = scenario.status
      end

      def has_image?
        not image.nil?
      end
    end

    class ReportStep
      attr_accessor :name, :keyword, :file_colon_line, :status, :duration, :table, :multiline_arg, :error

      def initialize(step)
        @name = step.name
        @file_colon_line = step.file_colon_line
        unless step.instance_of? Cucumber::Ast::Background
          if step.respond_to? :actual_keyword
            @keyword = step.actual_keyword
          else
            @keyword = step.keyword
          end
          @status = step.status
          @multiline_arg = step.multiline_arg
          @error = step.exception
        end
      end

      def failed_with_error?
        status == :failed && !error.nil?
      end

      def has_table?
        not table.nil?
      end
      def has_multiline_arg?
        !multiline_arg.nil? && !has_table?
      end
    end
  end
end
