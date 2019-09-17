# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceProtocol::Entity do
  let(:data) do
    { id: 1, full_name: 'Blah', rel_id: 7 }
  end

  describe 'context' do
    it 'works' do
      obj = { id: 1, type: 'ContextObj', attributes: { attr: 1 } }
      context = described_class.context(
        obj: obj,
        array: [obj.merge(id: 2), obj.merge(id: 3, type: 'Blah')]
      )
      expect(context).to be_a(OpenStruct)
      expect(context.obj._type).to eq('ContextObj')
      expect(context.obj.id).to eq(1)
      expect(context.obj.attr).to eq(1)

      expect(context.array).to be_a(Array)

      expect(context.array.first._type).to eq('ContextObj')
      expect(context.array.first.id).to eq(2)
      expect(context.array.first.attr).to eq(1)

      expect(context.array.last._type).to eq('Blah')
    end
  end

  describe '.build' do
    let(:class_name) { 'TestEntityBuild' }
    let(:entity) { described_class.build('TestEntityBuild', data) }

    it 'build a class Item that extends Struct' do
      expect(entity).to be_a(Struct)
      expect(entity).to be_a(TestEntityBuild)
    end

    it 'adds the data' do
      data.each do |k, v|
        expect(entity.send(k)).to eq(v)
      end
    end
  end

  describe '.build_all' do
    let(:class_name) { 'TestEntityBuildAll' }

    it 'allows you to edit each object during the loop' do
      numbers = [1, 2]
      array = described_class.build_all(class_name, [data, data]) do |obj|
        obj.rel = numbers.shift
      end

      expect(array[0].rel).to eq(1)
      expect(array[1].rel).to eq(2)
    end
  end

  describe '.build_all_hashed_on_id' do
    let(:class_name) { 'TestEntityBuildAllHashed' }

    it 'creates a hash with the objects keyed by their id' do
      hash = described_class.build_all_hashed_on_id(class_name, [data, data])
      hash.each do |k, v|
        expect(k).to eq(v.id)
      end
    end
  end

  describe '.class_for' do
    let(:class_name) { 'TestEntityClassFor' }
    let(:column_names) { [:attr1, :attr2, :rel_id] }
    let(:klass) { described_class.class_for(class_name, column_names) }

    it 'creates the constant' do
      expect(klass).to eq(ServiceProtocol.constantize(class_name))
    end

    it 'has all correct attributes' do
      expect(klass.new.to_h.keys).to eq(column_names + [:rel])
    end
  end

  describe '.context' do
    let(:context) { described_class.context(hash) }

    context 'when there are no errors' do
      let(:hash) do
        { errors: [] }
      end

      it 'success? == true' do
        expect(context).to be_success
      end

      it 'failure? == false' do
        expect(context).not_to be_failure
      end
    end

    context 'when there are errors' do
      let(:hash) do
        { errors: [1] }
      end

      it 'success? == false' do
        expect(context).not_to be_success
      end

      it 'failure? == true' do
        expect(context).to be_failure
      end
    end
  end
end
