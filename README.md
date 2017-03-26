# StaticModels

DRY your auxiliary singleton enumerations.
You know, those "key - value" classes.
Use them as associations on a parent model.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'static_models'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install static_models

## Usage

### Defining your models

```ruby
    # We're modelling Dogs, each of them has a Breed.
    # We support a static set of Breeds.

    class Breed
      # Enhance Breed to be a StaticModel
      include StaticModels::Model 

      # Our StaticModel instances can be defined as a table.
      # The first two columns are special:
      # 'id' must be a Fixnum, and will be used internally as primary key.
      # 'code' must be a Symbol, and will be used as a friendlier ID.
      # Class methods will be created to fetch a StaticModel instance by code.
      static_models_dense [
        [:id, :code,      :height ],
        [1,   :collie,    nil     ],
        [2,   :foxhound,  nil     ],
        [6,   :corgi,     'short' ],
        [7,   :doberman,  'tall'  ],
      ]
    end

    # You can find your Breed.
    Breed.find(6).tap do |b|
      # You also get class methods for accessing each singleton instance.
      b == Breed.corgi 

      b.code == :corgi
      b.height == 'short'
    end

    # Definitions can be sparse, no need to set a value for all attributes.
    Breed.collie.height == nil

    # 'All' just returns the ordered collection.
    Breed.all.should == [
      Breed.collie,
      Breed.foxhound,
      Breed.corgi,
      Breed.doberman
    ]

    # A low level 'values' dictionary is public.
    Breed.values.should == {
      1 => Breed.collie,
      2 => Breed.foxhound,
      6 => Breed.corgi,
      7 => Breed.doberman
    }

    # An alternative syntax is supported to use with sparse attribute definitions
    # Here's a definition of Breed with sparse attributes.
    class SparseBreed
      include StaticModels::Model
      static_models_sparse [
        [1, :collie],
        [2, :foxhound],
        [6, :corgi, height: 'short'],
        [7, :doberman,  height: 'tall'],
      ]
    end
```

### PORO's and ActiveRecords can belongs_to a StaticModel

```ruby

    # You point to your StaticModels like an ActiveRecords belongs_to association
    # Setting a Breed will update a breed_id attribute.
    class Dog
      attr_accessor :breed_id

      include StaticModels::BelongsTo
      belongs_to :breed
    end

    Dog.new.tap do |d|
      # Setting a Breed will update the underlying breed_id column.
      d.breed_id == nil
      d.breed = Breed.corgi
      d.breed_id == 6
      
      # Also, setting the breed_id column will update the Breed.
      d.breed_id = 7
      d.breed.should == Breed.doberman
    end

    # StaticModels::BelongsTo plays nice with ActiveRecords belongs_to.
    # You can use it in your models transparently, it will know
    # when to use a StaticModel or call out to ActiveRecord's code.
    # You can even set up polymorphic associations that point to either
    # a StaticModel or an ActiveRecord model.

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
    dog.breed == Breed.corgi
    dog.classification == Breed.collie
    dog.anything == Breed.doberman
    dog.store_dog == dog
    dog.another_dog == dog
    dog.anydog == dog

```

## Development

```sh
    $ bundle install
    $ bundle exec rspec spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bitex-la/static_models.

## Code Status

[![Build Status](https://circleci.com/gh/bitex-la/static_models.png)](https://circleci.com/gh/bitex-la/static_models)

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

