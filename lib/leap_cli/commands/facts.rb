#
# Gather facter facts
#

module LeapCli; module Commands

  desc 'Gather information on nodes.'
  command :facts do |facts|
    facts.desc 'Query servers to update facts.json.'
    facts.long_desc "Queries every node included in FILTER and saves the important information to facts.json"
    facts.arg_name 'FILTER'
    facts.command :update do |update|
      update.action do |global_options,options,args|
        update_facts(global_options, options, args)
      end
    end
  end

  protected

  def facter_cmd
    'facter --json ' + Leap::Platform.facts.join(' ')
  end

  def remove_node_facts(name)
    if file_exists?(:facts)
      update_facts_file({name => nil})
    end
  end

  def update_node_facts(name, facts)
    update_facts_file({name => facts})
  end

  def rename_node_facts(old_name, new_name)
    if file_exists?(:facts)
      facts = JSON.parse(read_file(:facts) || {})
      facts[new_name] = facts[old_name]
      facts[old_name] = nil
      update_facts_file(facts, true)
    end
  end

  #
  # if overwrite = true, then ignore existing facts.json.
  #
  def update_facts_file(new_facts, overwrite=false)
    replace_file!(:facts) do |content|
      if overwrite || content.nil? || content.empty?
        old_facts = {}
      else
        old_facts = JSON.parse(content)
      end
      facts = old_facts.merge(new_facts)
      facts.each do |name, value|
        if value.is_a? String
          if value == ""
            value = nil
          else
            value = JSON.parse(value)
          end
        end
        if value.is_a? Hash
          value.delete_if {|key,v| v.nil?}
        end
        facts[name] = value
      end
      facts.delete_if do |name, value|
        value.nil? || value.empty?
      end
      if facts.empty?
        nil
      else
        JSON.sorted_generate(facts) + "\n"
      end
    end
  end

  private

  def update_facts(global_options, options, args)
    nodes = manager.filter(args, :local => false)
    new_facts = {}
    ssh_connect(nodes) do |ssh|
      ssh.leap.run_with_progress(facter_cmd) do |response|
        node = manager.node(response[:host])
        if node
          new_facts[node.name] = response[:data].strip
        else
          log :warning, 'Could not find node for hostname %s' % response[:host]
        end
      end
    end
    overwrite_existing = args.empty?
    update_facts_file(new_facts, overwrite_existing)
  end

end; end