require 'eventstore'
module StreamWorker
  def run!
    default = 'http://0.0.0.0:2113'
    @eventstore = EventStore::Client.new ENV['EVENTSTORE_URL'] || default
    state = Hash.new
    EventStore::Util.poll(@eventstore, @stream).each do |event|
      @handler.call state, event
    end
  end
  def handle stream, &blk
    @stream = stream
    @handler = blk
  end
  def emit stream, event_type, data
    @eventstore.write_event stream, event_type, data
  end
end
include StreamWorker
at_exit do
  if $!.nil?
    puts "RUNNING"
    run!
    puts "DONE RUNNING"
  end
end
