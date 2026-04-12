# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class PythonWorkerClient
  DEFAULT_ENDPOINT = 'http://127.0.0.1:5000/enqueue'

  class Error < StandardError; end

  class << self
    def enqueue(test_run_id)
      response = perform_request(test_run_id)

      unless response.code.to_i == 202
        raise Error, "Python worker responded with #{response.code}: #{response.body}"
      end

      parse_task_id(response.body)
    rescue JSON::ParserError => e
      raise Error, "Unable to parse python worker response: #{e.message}"
    rescue StandardError => e
      raise Error, "Failed to enqueue Python worker job: #{e.message}"
    end

    private

    def perform_request(test_run_id)
      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request.body = { test_run_id: test_run_id }.to_json

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
    end

    def endpoint
      ENV.fetch('PYTHON_WORKER_API', DEFAULT_ENDPOINT)
    end

    def parse_task_id(body)
      payload = JSON.parse(body)
      payload['task_id'] || raise(Error, 'Python worker response missing task_id')
    end
  end
end
