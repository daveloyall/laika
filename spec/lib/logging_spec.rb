require File.dirname(__FILE__) + '/../spec_helper'

describe "Logging" do

  class TestLogging
    include Logging
  end

  class NestedLogging < TestLogging
    attr_accessor :root
    def root?
      !self.root
    end
  end

  before do
    @l = TestLogging.new
    @mock_logger = mock("logger")
  end

  it "should use logger if logger is set" do
    @l.logger = @mock_logger
    @mock_logger.should_receive(:debug).once.with("\e[4;32;1mTestLogging\e[0m : foo")
    @l.debug("foo")
  end

  it "should print to STDERR if logger is not set" do
    silence_warnings do
      old_fallback = Logging::FALLBACK
      Logging::FALLBACK = @mock_logger
      @mock_logger.should_receive(:puts).once.with("DEBUG : \e[4;32;1mTestLogging\e[0m : foo")
      @l.debug("foo")
      Logging::FALLBACK = old_fallback
    end
  end

  it "should use logger if root logger is set" do
    @l.logger = @mock_logger
    @mock_logger.should_receive(:debug).once.with("\e[4;32;1mNestedLogging\e[0m : foo")
    c = NestedLogging.new
    c.root = @l
    c.debug("foo")
  end

end
