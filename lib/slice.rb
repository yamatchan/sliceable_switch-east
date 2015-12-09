require 'active_support/core_ext/class/attribute_accessors'
require 'json'
require 'path_manager'
require 'port'
require 'slice_exceptions'
require 'slice_extensions'

# Virtual slice.
# rubocop:disable ClassLength
class Slice
  extend DRb::DRbUndumped
  include DRb::DRbUndumped

  cattr_accessor(:all, instance_reader: false) { [] }

  def self.create(name)
    if find_by(name: name)
      fail SliceAlreadyExistsError, "Slice #{name} already exists"
    end
    unless /^[\w\-]+$/ === name
      fail SliceNameValidationError, "Slice name (#{name}) is validation error"
    end
    new(name).tap { |slice| all << slice }
  end

  def self.find_by(queries)
    queries.inject(all) do |memo, (attr, value)|
      memo.find_all do |slice|
        slice.__send__(attr) == value
      end
    end.first
  end

  def self.find_by!(queries)
    find_by(queries) || fail(SliceNotFoundError,
                             "Slice #{queries.fetch(:name)} not found")
  end

  def self.find(&block)
    all.find(&block)
  end

  def self.destroy(name)
    find_by!(name: name)
    Path.find { |each| each.slice == name }.each(&:destroy)
    all.delete_if { |each| each.name == name }
  end

  def self.destroy_all
    all.clear
  end

  def self.join(merge_slice_name, into)
    slices = []
    into.split(",").each do |slice_name|
      if Slice.find_by(name: slice_name).nil?
        fail SliceNotFoundError, "Slice #{slice_name} not found"
      end
      slices.push(slice_name)
    end
    slices.uniq!

    slice = Slice.find_by(name: merge_slice_name)
    slice = Slice.create(merge_slice_name) if slice.nil?

    slices.each do |slice_name|
      slice.get_ports.merge!(Slice.find_by!(name: slice_name).get_ports)
      Slice.destroy(slice_name)
    end
  end

  attr_reader :name

  def initialize(name)
    @name = name
    @ports = Hash.new([].freeze)
  end
  private_class_method :new

  def add_port(port_attrs)
    port = Port.new(port_attrs)
    if @ports.key?(port)
      fail PortAlreadyExistsError, "Port #{port.name} already exists"
    end
    @ports[port] = [].freeze
  end

  def delete_port(port_attrs)
    find_port port_attrs
    Path.find { |each| each.slice == @name }.select do |each|
      each.port?(Topology::Port.create(port_attrs))
    end.each(&:destroy)
    @ports.delete Port.new(port_attrs)
  end

  def find_port(port_attrs)
    mac_addresses port_attrs
    Port.new(port_attrs)
  end

  def each(&block)
    @ports.keys.each do |each|
      block.call each, @ports[each]
    end
  end

  def ports
    @ports.keys
  end

  def get_ports
    @ports
  end

  def add_mac_address(mac_address, port_attrs)
    port = Port.new(port_attrs)
    if @ports[port].include? Pio::Mac.new(mac_address)
      fail(MacAddressAlreadyExistsError,
           "MAC address #{mac_address} already exists")
    end
    @ports[port] += [Pio::Mac.new(mac_address)]
  end

  def delete_mac_address(mac_address, port_attrs)
    find_mac_address port_attrs, mac_address
    @ports[Port.new(port_attrs)] -= [Pio::Mac.new(mac_address)]

    Path.find { |each| each.slice == @name }.select do |each|
      each.endpoints.include? [Pio::Mac.new(mac_address),
                               Topology::Port.create(port_attrs)]
    end.each(&:destroy)
  end

  def find_mac_address(port_attrs, mac_address)
    find_port port_attrs
    mac = Pio::Mac.new(mac_address)
    if @ports[Port.new(port_attrs)].include? mac
      mac
    else
      fail MacAddressNotFoundError, "MAC address #{mac_address} not found"
    end
  end

  def mac_addresses(port_attrs)
    port = Port.new(port_attrs)
    @ports.fetch(port)
  rescue KeyError
    raise PortNotFoundError, "Port #{port.name} not found"
  end

  def split(into)
    slices = {}
    into.split(" ").each {|item|
      next if item.strip == ""
      item.scan(/^([\w\-]+):([\w\-:,]+)$/) do |slice_name, ports_str|
        unless Slice.find_by(name: slice_name).nil?
          fail SliceAlreadyExistsError, "Slice #{slice_name} already exists"
        end

        slices[slice_name] = []
        ports_str.split(",").each do |port_str|
          port = Port.new(Port.parse(port_str))
          unless @ports.has_key? port
            fail PortNotFoundError, "Port #{port.name} not found"
          end
          slices[slice_name].push port
        end
      end
    }

    slices.map do |slice_name, ports|
      Slice.create slice_name
      ports.each do |port|
        Slice.find_by!(name: slice_name).get_ports[port] += @ports[port]
        @ports.delete(port)
      end
    end
  end

  def member?(host_id)
    @ports[Port.new(host_id)].include? host_id[:mac]
  rescue
    false
  end

  def to_s
    @name
  end

  def to_json(*_)
    %({"name": "#{@name}"})
  end

  def method_missing(method, *args, &block)
    @ports.__send__ method, *args, &block
  end
end
# rubocop:enable ClassLength
