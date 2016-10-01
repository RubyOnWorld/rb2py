
class ClassNode

  def real_gen
    includes = filter_children IncludeNode
    $pygen.class(@class_name, ($pygen.py_class_name ancestor.to_s), decorators, includes) do

      gen_init

      for child in children
        $pygen.statement child
      end
      gen_methods_for_attributes
    end
  end

  def gen_init
    if initialize_method = find_initialize?
      initialize_method.gen do
        gen_children AttributeNode
        $pygen.indent 'super().__init__()' unless calls_super_initialize
      end
    elsif has_attributes?
      $pygen.method '__init__' do
        $pygen.argument '*args'
        $pygen.body do
          gen_children AttributeNode
          $pygen.indent 'super().__init__(*args)'
        end
      end
    end
  end

  def no_ancestor?
    ancestor_name == '' and (filter_children IncludeNode).size == 0
  end

  def find_initialize?
    @children.find &:initialize?
  end

  def has_attributes?
    filter_children(AttributeNode).size > 0
  end

  def gen_instance_call(message_name, target, &block)
    m = find_method message_name
    message_name = m.new_name if m
    $pygen.call message_name, target, &block
  end

  def gen_methods_for_attributes
    for attr in attributes
      gen_getter attr
      gen_setter attr
    end
    for attr in static_attributes
      gen_static_getter attr
      gen_static_setter attr
    end
  end

  def gen_getter(attr)
    # if there is explicit getter, skip generation
    return if has_or_inherits_method? attr.name
    $pygen.method attr.name do
      $pygen.body do
        $pygen.indent
        $pygen.write "return self._#{attr.name}"
      end
    end
  end

  def gen_static_getter(attr)
    # if there is explicit getter, skip generation
    return if has_method? attr.name
    $pygen.method attr.name, false, ['@staticmethod'] do
      $pygen.body do
        $pygen.indent
        $pygen.write "return #{fullname.last_part}._#{attr.name}"
      end
    end
  end

  def gen_setter(attr)
    setter_name = make_setter_name attr.name
    # if there is explicit setter, skip generation
    unless has_or_inherits_method? setter_name
      # If we dont pass generated_block:false, $pygen would think that it is function autogenerated for block
      # emulation if attr.name starts with "block".
      $pygen.method(setter_name, generated_block:false) {
        $pygen.argument 'value'
        $pygen.body {
          $pygen.indent
          $pygen.write "self._#{attr.name} = value"
        }
      }
    end
    special_setter_name = "_#{attr.name}_setter"
    $pygen.method(special_setter_name, generated_block:false) {
      $pygen.argument 'value'
      $pygen.body {
        $pygen.indent
        $pygen.write "self.#{setter_name}(value)"
      }
    }
    $pygen.indent "#{special_setter_name} = property(None, #{special_setter_name}, None)"
    $pygen.comment "Setter used for multiple assignment"
  end

  def gen_static_setter(attr)
    setter_name = make_setter_name attr.name
    # if there is explicit setter, skip generation
    return if has_method? setter_name
    $pygen.method setter_name, false, ['@staticmethod'] do
      $pygen.argument 'value'
      $pygen.body do
        $pygen.indent
        $pygen.write "#{fullname.last_part}._#{attr.name} = value"
      end
    end
  end
end