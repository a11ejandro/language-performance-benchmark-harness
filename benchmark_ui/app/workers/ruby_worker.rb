require 'rbconfig'
require 'fiddle'
require 'fiddle/import'

class RubyWorker
  include Sidekiq::Job

  def perform(test_run_id)
    test_run = TestRun.find(test_run_id)
    task = test_run.handler.task
    page_size = task.per_page
    page = task.page
    values = get_page_values(page, page_size)

    measurement, peak_memory = measure_peak_resident_memory do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stats = CalculateStatistics.call(values)
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      [stats, duration]
    end

    results, duration = measurement

    TestResult.create!(**results, test_run: test_run, duration:, memory: peak_memory)
  end

  private

  def get_page_values(page, per_page)
    offset = per_page * ((page = page.to_i - 1) < 0 ? 0 : page)

    Sample.limit(per_page).offset(offset).pluck(:value)
  end

  SAMPLING_INTERVAL = 0.01

  def measure_peak_resident_memory
    baseline = rss_bytes || 0
    peak = baseline
    running = true

    sampler = Thread.new do
      while running
        current = rss_bytes
        peak = current if current && current > peak
        sleep SAMPLING_INTERVAL
      end
    end

    value = yield
    peak ||= baseline
    [value, peak]
  ensure
    running = false if defined?(running)
    sampler&.join if defined?(sampler)
  end

  def rss_bytes
    return statm_resident_bytes if linux?
    return macos_resident_bytes if mac?

    ps_resident_bytes
  rescue StandardError
    0
  end

  def linux?
    RbConfig::CONFIG['host_os']&.match?(/linux/i)
  end

  def mac?
    RbConfig::CONFIG['host_os']&.match?(/darwin/i)
  end

  def statm_resident_bytes
    statm = File.read("/proc/#{Process.pid}/statm").split
    pages = statm[1].to_i
    pages * page_size
  end

  module MacProcessInfo
    extend Fiddle::Importer

    begin
      dlload '/usr/lib/libSystem.B.dylib'
      PROC_PIDTASKINFO = 4
      BUFFER_SIZE = 64

      extern 'int proc_pidinfo(int, int, uint64_t, void*, int)'
    rescue Fiddle::DLError
      # Leave module without bindings; caller will handle nil response
    end

    module_function

    def resident_bytes(pid)
      return unless respond_to?(:proc_pidinfo)

      buffer = Fiddle::Pointer.malloc(BUFFER_SIZE)
      size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, buffer, BUFFER_SIZE)
      return if size <= 0

      buffer[8, 8].unpack1('Q')
    rescue Fiddle::DLError
      nil
    end
  end

  def macos_resident_bytes
    MacProcessInfo.resident_bytes(Process.pid) || ps_resident_bytes
  end

  def ps_resident_bytes
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    rss_kb * 1024
  end

  def page_size
    @page_size ||= begin
      Integer(`getconf PAGESIZE`.strip)
    rescue Errno::ENOENT, ArgumentError
      4096
    end
  end
end
