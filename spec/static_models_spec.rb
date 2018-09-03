require "spec_helper"

class Breed
  include StaticModels::Model
  static_models_dense [
    [:id, :code,      :height ],
    [1,   :collie,    nil     ],
    [2,   :foxhound,  nil     ],
    [6,   :corgi,     'short' ],
    [7,   :doberman,  'tall'  ],
  ]
end

class Dog
  attr_accessor :breed_id, :anything_id, :anything_type

  include StaticModels::BelongsTo
  belongs_to :breed
  belongs_to :anything, polymorphic: true
end

describe StaticModels::Model do

  it "defines and uses a static model" do
    Breed.corgi.tap do |b|
      b.should == Breed.find(6)
      b.code.should == :corgi
      b.height.should == 'short'
    end

    Breed.doberman.tap do |b|
      b.id.should == 7
      b.height.should == 'tall'
    end

    Breed.collie.height.should be_nil

    Breed.all.should == [
      Breed.collie,
      Breed.foxhound,
      Breed.corgi,
      Breed.doberman
    ]

    Breed.values.should == {
      1 => Breed.collie,
      2 => Breed.foxhound,
      6 => Breed.corgi,
      7 => Breed.doberman
    }
  end

  it "has a model name" do
    Breed.model_name.plural.should == "breeds"
  end

  it "has an AR like 'where', but dummy" do
    Breed.where.should == Breed.all
  end

  it "has a find_by_code method" do
    Breed.find_by_code('corgi').should == Breed.corgi 
    Breed.find_by_code(:corgi).should == Breed.corgi 
    Breed.find_by_code(nil).should == nil
    Breed.find_by_code([]).should == nil
  end

  it "#to_s" do
    Breed.collie.to_s.should == 'collie'
  end

  it "#to_i" do
    Breed.collie.to_i.should == 1
  end

  it '#name' do
    Breed.collie.name.should == :collie
  end

  it 'Defines static model values using a dense table' do
    class SparseBreed
      include StaticModels::Model
      static_models_sparse [
        [1, :collie],
        [2, :foxhound],
        [6, :corgi, height: 'short'],
        [7, :doberman,  height: 'tall'],
      ]
    end

    SparseBreed.values.zip(Breed.values).each do |sparse, dense|
      sparse.first.should == dense.first
      sparse.last.code.should == dense.last.code
      sparse.last.height.should == dense.last.height
    end
  end

  describe 'when checking malformed definitions' do
    def self.check_def(title, &blk)
      it title do
        expect do
          Class.new do
            include StaticModels::Model
            instance_eval &blk
          end
        end.to raise_exception(StaticModels::ValueError)
      end
    end

    def self.checks_dense(title, *table)
      check_def("checks dense "+ title) do static_models_dense(table) end
    end

    def self.checks_sparse(title, *table)
      check_def("checks sparse "+ title) do static_models_sparse(table) end
    end

    checks_sparse "id is Fixnum", ["hello", :foo]
    checks_sparse "code is Symbol", [1, 2323]
    checks_sparse "has only id, code, and Hash", [1, :bar, :ble, foo: :bar]
    checks_sparse "codes are unique", [1, :foo], [2, :foo]
    checks_sparse "columns are symbols", [1, :foo, [] => :baz]

    checks_dense "id is Fixnum", [:id, :code], ["hello", :foo]
    checks_dense "invalid code type", [:id, :code], [1, 2323]
    checks_dense "has id and code", [:id, :code, :other], [1,]
    checks_dense "codes are unique", [:id, :code], [1, :foo], [2, :foo]
    checks_dense "columns are symbols", [:id, :code, []], [1, :foo, :baz]
  end
end

describe StaticModels::BelongsTo do
  it "can be used as an association" do
    Dog.new.tap do |d|
      d.breed_id.should be_nil
      d.breed = Breed.corgi
      d.breed_id.should == 6

      d.breed_id = 7
      d.breed.should == Breed.doberman
    end
  end

  it "can be used as a polymorphic association" do
    Dog.new.tap do |d|
      d.anything_id.should be_nil
      d.anything_type.should be_nil
      d.anything = Breed.corgi
      d.anything_id.should == 6
      d.anything_type.should == 'Breed'

      d.anything_id = 7
      d.anything.should == Breed.doberman
    end
  end

  it "can receive a specific class name for association" do
    class WeirdDoggie
      attr_accessor :dog_kind_id

      include StaticModels::BelongsTo
      belongs_to :dog_kind, class_name: 'Breed'

      a = WeirdDoggie.new.tap do |d|
        d.dog_kind = Breed.corgi
        d.dog_kind_id = 6
        d.dog_kind_code = 'corgi'
      end      
    end
  end

  it "can receive code representation for association" do
    class AnotherWeirdDoggie
      attr_accessor :dog_kind_id

      include StaticModels::BelongsTo
      belongs_to :dog_kind, class_name: 'Breed'
    end

    a = AnotherWeirdDoggie.new.tap do |d|
      d.dog_kind_code = 'corgi'
    end

    a.dog_kind.should == Breed.corgi
    a.dog_kind_code.should == :corgi
  end

  it "does not fail if using bogus values for association code" do
    expect do 
      d = Dog.new
      d.breed_code = 3333
      d.breed.should be_nil
      d.breed_code = "nothing"
      d.breed.should be_nil
    end.not_to raise_exception
  end

  it "finds local and global models when guessing association class" do
    module DogHouse
      class LocalBreed
        include StaticModels::Model
        static_models_sparse [
          [1, :local_collie],
          [2, :local_foxhound],
        ]
      end

      class LocalDoggie
        attr_accessor :breed_id
        attr_accessor :local_breed_id

        include StaticModels::BelongsTo
        belongs_to :breed
        belongs_to :local_breed
      end

      LocalDoggie.new.tap do |d|
        d.breed = Breed.collie
        d.local_breed = LocalBreed.local_collie
        d.breed.should == Breed.collie
        d.local_breed.should == LocalBreed.local_collie
      end
    end
  end

  it "raises when types don't match" do
    expect do
      Dog.new.breed = 3333
    end.to raise_exception(StaticModels::ValueError)
  end

  it 'allows assigning nil' do
    dog = Dog.new
    dog.breed = Breed.corgi
    dog.breed = nil
    dog.breed_id.should be_nil
    dog.breed.should be_nil
    dog.anything = Breed.doberman
    dog.anything = nil
    dog.anything_id.should be_nil
    dog.anything_type.should be_nil
    dog.anything.should be_nil
  end

  describe 'when used on an ActiveRecord model' do
    class StoreDog < ActiveRecord::Base
      include StaticModels::BelongsTo
      belongs_to :breed
      belongs_to :classification, class_name: 'Breed'
      belongs_to :anything, polymorphic: true
      belongs_to :store_dog
      belongs_to :another_dog, class_name: 'StoreDog'
      belongs_to :anydog, polymorphic: true
    end

    before(:each) do
      setup_database!
      run_migration do
        create_table(:store_dogs, force: true) do |t|
          t.integer :breed_id
          t.integer :classification_id
          t.integer :anything_id
          t.string :anything_type
          t.integer :store_dog_id
          t.integer :another_dog_id
          t.integer :anydog_id
          t.string :anydog_type
        end
      end
    end
    after(:each) { cleanup_database! }

    it "can be used on belongs to" do
      dog = StoreDog.new
      dog.breed = Breed.corgi
      dog.classification = Breed.collie
      dog.anything = Breed.doberman
      dog.store_dog = dog
      dog.another_dog = dog
      dog.anydog = dog
      dog.save!
      dog.reload
      dog.breed.should == Breed.corgi
      dog.classification.should == Breed.collie
      dog.anything.should == Breed.doberman
      dog.store_dog.should == dog
      dog.another_dog.should == dog
      dog.anydog.should == dog

      dog.anything = dog
      dog.anydog = Breed.foxhound
      dog.save!
      dog.reload
      dog.anything.should == dog
      dog.anydog.should == Breed.foxhound
    end

    it 'allows assigning nil' do
      dog = StoreDog.new
      dog.breed = Breed.corgi
      dog.classification = Breed.collie
      dog.anything = Breed.doberman
      dog.store_dog = dog
      dog.another_dog = dog
      dog.anydog = dog
      dog.save!
      dog.reload

      dog.breed = nil
      dog.classification = nil
      dog.anything = nil
      dog.store_dog = nil
      dog.another_dog = nil
      dog.anydog = nil
      dog.save!
      dog.reload

      dog.breed.should be_nil
      dog.classification.should be_nil
      dog.anything.should be_nil
      dog.store_dog.should be_nil
      dog.another_dog.should be_nil
      dog.anydog.should be_nil
    end

    it 'handles basic validations gracefully' do
      class ValidDog < ActiveRecord::Base
        include StaticModels::BelongsTo
        belongs_to :breed
        belongs_to :anything, polymorphic: true
        validates :breed, :anything, presence: true
        validates :breed, uniqueness: true
        validates_associated :breed
      end

      run_migration do
        create_table(:valid_dogs, force: true) do |t|
          t.integer :breed_id
          t.integer :anything_id
          t.string :anything_type
        end
      end

      dog = ValidDog.new
      dog.should_not be_valid
      dog.update(breed: Breed.corgi, anything: Breed.doberman)
      dog.should be_valid
      dog.update(anything: dog)
      dog.should be_valid
    end
  end
end
