# frozen_string_literal: true

# Stubs each instance a class builds with .new, in place of allow_any_instance_of:
#
#   on_new_instances(Granblue::Parsers::Wiki) do |wiki|
#     allow(wiki).to receive(:fetch).and_return('{{Page}}')
#   end
#
# Only instances built with .new after the call are stubbed, not records loaded
# from the database. Calls add up: a later call (say, a `.with` stub in an
# example) applies on top of the ones before it.
module NewInstanceStubs
  def on_new_instances(klass, &stub)
    stubs = new_instance_stubs[klass]
    stubs << stub
    return if stubs.size > 1

    allow(klass).to receive(:new).and_wrap_original do |original, *args, **kwargs, &block|
      original.call(*args, **kwargs, &block).tap { |instance| stubs.each { |each_stub| each_stub.call(instance) } }
    end
  end

  private

  def new_instance_stubs
    @new_instance_stubs ||= Hash.new { |hash, klass| hash[klass] = [] }
  end
end

RSpec.configure { |config| config.include NewInstanceStubs }
