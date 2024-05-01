require 'net/http'
require 'json'
require 'time'

class GitHubActivityLogger
  GITHUB_API_BASE = "https://api.github.com".freeze
  NUMBER_OF_HOURS = 50
  TIME_DIFFERENCE = NUMBER_OF_HOURS * 3600

  def initialize(username = ENV['GITHUB_USERNAME'], token = ENV['GITHUB_TOKEN'])
    @username = username
    @token = token
    @events_cache = []
  end

  def log_activities
    puts "Starting to log activities for #{@username}..."
    fetch_github_events
    process_events
    save_activity_log
    puts "Finished logging activities for #{@username}. Check eod.md for details."
  end

  private

  def fetch_github_events
    puts "Fetching GitHub events for #{@username}..."
    uri = URI("#{GITHUB_API_BASE}/users/#{@username}/events")
    response = make_http_request(uri)
    @events_cache = parse_response(response)
  end

  def parse_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    puts "Oops! There was an error parsing the response: #{e.message}"
    []
  rescue StandardError => e
    puts "Oops! Something went wrong: #{e.message}"
    []
  end

  def make_http_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@token}"

    http.request(request)
  end

  def process_events
    @activity_log = {}
    @events_cache.each do |event|
      process_event(event)
    end
  end

  def process_event(event)
    return unless Time.parse(event['created_at']) > Time.now - TIME_DIFFERENCE

    event_type = event['type']
    event_processor = {
      'PullRequestReviewEvent' => method(:process_pr_review_event),
      'IssuesEvent' => method(:process_issue_pr_event),
      'PullRequestEvent' => method(:process_issue_pr_event),
      'PushEvent' => method(:process_push_event)
    }[event_type]

    event_processor.call(event) if event_processor
  end

  def process_pr_review_event(event)
    pr_name = event['payload']['pull_request']['title']
    pr_link = event['payload']['pull_request']['html_url']
    author_name = event['payload']['pull_request']['user']['login']
    @activity_log["Reviewed a pull request: [#{pr_name}](#{pr_link}) by _#{author_name}_"] = nil
  end

  def process_issue_pr_event(event)
    event_key, head_text = event['type'] == 'IssuesEvent' ? ['issue', 'Created an issue'] : ['pull_request', 'Opened a pull request']

    if event['payload'][event_key] && event['payload']['action'] == 'opened'
      title = event['payload'][event_key]['title']
      link = event['payload'][event_key]['html_url']
      @activity_log["#{head_text}: [#{title}](#{link})"] = nil
    end
  end

  def process_push_event(event)
    repo_name = event['repo']['name']
    branch_name = event['payload']['ref'].split('/').last
    @activity_log[repo_name] ||= {}
    @activity_log[repo_name][branch_name] ||= []
    event['payload']['commits'].each do |commit|
      @activity_log[repo_name][branch_name] << commit['message']
    end
  end

  def save_activity_log
    log_filename = "eod.md"
    contents = @activity_log.map do |activity, details|
      if details.nil?
        "- #{activity}\n"
      else
        details.map { |branch, commits|
          "- Committed changes to _#{activity}##{branch}_:\n" + commits.map { |commit| "  - #{commit}\n" }.join
        }.join
      end
    end.join

    contents = ["**#{Date.today.to_s}**","**Done**", contents].join("\n")
    puts "----------------------------------------"
    puts contents
    puts "----------------------------------------"
    File.write(log_filename, contents)
    puts "Activities logged to #{log_filename}."
  end
end

github_username = ENV['GITHUB_USERNAME']
github_token = ENV['GITHUB_TOKEN']

# Check if the required environment variables are present
unless github_username && github_token
  puts "Please set the GITHUB_USERNAME and GITHUB_TOKEN environment variables."
  exit 1
end

logger = GitHubActivityLogger.new(github_username, github_token)
logger.log_activities
