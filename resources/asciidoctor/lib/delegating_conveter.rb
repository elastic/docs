# frozen_string_literal: true

##
# Abstract base for implementing a converter that implements some conversions
# and delegates the rest to the "next" converter.
class DelegatingConverter
  ##
  # Setup a converter on a document.
  def self.setup(document)
    converter = yield document.converter
    document.instance_variable_set :@converter, converter
  end

  def initialize(delegate)
    @delegate = delegate
  end

  def convert(node, transform = nil, opts = {})
    # The behavior of this method mirrors Asciidoctor::Base.convert
    t = transform || node.node_name
    if respond_to? t
      send t, node do
        # Passes a block that subclasses can call to run the converter chain.
        @delegate.convert node, transform, opts
      end
    else
      @delegate.convert node, transform, opts
    end
  end
end
