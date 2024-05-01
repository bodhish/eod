require 'net/http'
require 'json'
require 'time'

class GitHubActivityLogger
  GITHUB_API_BASE = "https://api.github.com".freeze
  NUMBER_OF_HOURS = 24
  TIME_DIFFERENCE = NUMBER_OF_HOURS * 3600

  def initialize(username = ENV['GITHUB_USERNAME'], token = ENV['GITHUB_TOKEN'])
    @username = username
    @token = token
  end

  def log_activities
    events = fetch_github_events
    activity_log = process_events(events)
    save_activity_log(activity_log)
  end

  private

  def fetch_github_events
    puts "Fetching GitHub events for #{@username}..."
    uri = URI("#{GITHUB_API_BASE}/users/#{@username}/events")
    response = make_http_request(uri)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    puts "Error parsing the response: #{e.message}"
    []
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
    []
  end

  def make_http_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@token}"

    http.request(request)
  end

  def process_events(events)
    activity_log = {}
    events.each do |event|
      process_event(event, activity_log)
    end
    activity_log
  end

  def process_event(event, activity_log)
    return unless Time.parse(event['created_at']) > Time.now - TIME_DIFFERENCE

    event_type = event['type']
    event_processor = {
      'PullRequestReviewEvent' => method(:process_pr_review_event),
      'IssuesEvent' => method(:process_issue_pr_event),
      'PullRequestEvent' => method(:process_issue_pr_event),
      'PushEvent' => method(:process_push_event)
    }[event_type]

    event_processor.call(event, activity_log) if event_processor
  end

  def process_pr_review_event(event, activity_log)
    pr_name = event['payload']['pull_request']['title']
    pr_link = event['payload']['pull_request']['html_url']
    author_name = event['payload']['pull_request']['user']['login']
    activity_log["Reviewed PR: [#{pr_name}](#{pr_link}) by _#{author_name}_"] = nil
  end

  def process_issue_pr_event(event, activity_log)
    event_key = event['type'] == 'IssuesEvent' ? 'issue' : 'pull_request'

    if event['payload'][event_key] && event['payload']['action'] == 'opened'
      title = event['payload'][event_key]['title']
      link = event['payload'][event_key]['html_url']
      activity_log["Opened #{event['type'].chomp('Event')}: [#{title}](#{link})"] = nil
    end
  end

  def process_push_event(event, activity_log)
    repo_name = event['repo']['name']
    branch_name = event['payload']['ref'].split('/').last
    activity_log[repo_name] ||= {}
    activity_log[repo_name][branch_name] ||= []
    event['payload']['commits'].each do |commit|
      activity_log[repo_name][branch_name] << commit['message']
    end
  end

  def save_activity_log(activity_log)
    log_filename = "eod.md"
    contents = activity_log.map do |activity, details|
      if details.nil?
        "- #{activity}\n"
      else
        details.map { |branch, commits|
          "- Committed changes to _#{activity}##{branch}_:\n" + commits.map { |commit| "  - #{commit}\n" }.join
        }.join
      end
    end.join

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

puts "Logging GitHub activities for #{github_username}..."
logger = GitHubActivityLogger.new(github_username, github_token)
logger.log_activities
