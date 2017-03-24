require "spec_helper"

class Breed
  include StaticModels::Model
  static_models(
    1 => :collie,
    2 => :foxhound,
    6 => [:corgi, height: 'short'],
    7 => [:doberman, height: 'tall']
  )
end

class Dog
  attr_accessor :breed_id

  include StaticModels::BelongsTo
  belongs_to :breed
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

  it "#to_s" do
    Breed.collie.to_s.should == 'collie'
  end

  it "#to_i" do
    Breed.collie.to_i.should == 1
  end

  it '#name' do
    Breed.collie.name.should == :collie
  end

  def self.it_raises_checking(title, exception, attributes)
    it "raises checking #{title}" do
      expect do
        Class.new do
          include StaticModels::Model
          static_models(attributes)
        end
      end.to raise_exception(exception)
    end
  end

  it_raises_checking "keys type",
    StaticModels::TypeError, "hello" => :foo

  it_raises_checking "codes type",
    StaticModels::TypeError, 1 => 2323

  it_raises_checking "extended attributes types",
    StaticModels::TypeError, 1 => [:bar, :ble, foo: :bar]

  it_raises_checking "codes are unique",
    StaticModels::DuplicateCodes, 1 => :foo, 2 => :foo 
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

  it "can receive a specific class for association" do
    class WeirdDoggie
      attr_accessor :dog_kind_id

      include StaticModels::BelongsTo
      belongs_to :dog_kind, class_name: 'Breed'

      WeirdDoggie.new.tap do |d|
        d.dog_kind = Breed.corgi
        d.dog_kind_id = 6
      end
    end
  end

  it "raises when types don't match" do
    expect do
      Dog.new.breed = 3333
    end.to raise_exception(StaticModels::TypeError)
  end

  it "can be used on belongs to" do
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

    class StoreDog < ActiveRecord::Base
      include StaticModels::BelongsTo
      belongs_to :breed
      belongs_to :classification, class_name: 'Breed'
      belongs_to :anything, polymorphic: true
      belongs_to :store_dog
      belongs_to :another_dog, class_name: 'StoreDog'
      belongs_to :anydog, polymorphic: true
    end

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

    cleanup_database!
  end
end
