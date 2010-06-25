class Object

  # Yields self and returns self, allowing you to inject an arbitrary block
  # into a method chain.  Provides the 1.9 tap in 1.8.
  #
  # a_string = 'Hello World'
  #
  # a_string.tap { |s| puts s }.reverse 
  # 'Hellow World'
  # => 'dlroW olleH'
  def tap
    yield self
    self
  end unless respond_to?(:tap)

  # Synonmous with send, except that it first checks to see if the
  # target responds to requested method.  If not, will return Nil
  # instead of raising a NoMethodError.
  def try(method, *args, &block)
    send(method, *args, &block) if respond_to?(method)
  end unless respond_to?(:try)

end
