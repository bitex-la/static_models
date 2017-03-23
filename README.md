# StaticModels

DRY your accesory "key - value" classes. Use them as associations on a parent model.

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

```ruby
    # We're modelling Dog's, each of them has a Breed.
    # We support a static set of Breeds.

    class Breed
      # Enhance Breed to be a StaticModel
      include StaticModels::Model 

      # Actually define the breeds we support using a Hash
      # Keys are the 'id' attribute of each model. Must be Integers.
      # Values are the 'code' attribute. Must be Symbols, and unique.
      # If you want your model to have extra attributes, make te value
      # be an Array of 2 elements: [Symbol, Hash].
      static_models(
        1 => :collie,
        2 => :foxhound,
        6 => [:corgi, height: 'short'],
        7 => [:doberman, height: 'tall']
      )
    end

    # You can find your Breed.
    Breed.find(6).tap do |b|
      # You also get class methods for accessing each singleton instance.
      b == Breed.corgi 

      b.code == :corgi
      b.height == 'short'
    end

    # Definitions can be sparse, no need to set a value for all attributes.
    Breed.collie.height.should be_nil

    # All just returns the ordered collection.
    Breed.all.should == [
      Breed.collie,
      Breed.foxhound,
      Breed.corgi,
      Breed.doberman
    ]

    # The low level 'values' dictionary is public.
    Breed.values.should == {
      1 => Breed.collie,
      2 => Breed.foxhound,
      6 => Breed.corgi,
      7 => Breed.doberman
    }

    # You can use your StaticModels similar to an association.
    # Setting a Breed will update a breed_id attribute.
    class Dog
      attr_accessor :breed_id

      include StaticModels::BelongsTo
      belongs_to_static_model :breed
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

    # Set your model manually if it can't be inferred from the attribute name

    class WeirdDoggie
      attr_accessor :dog_kind_id

      include StaticModels::BelongsTo
      belongs_to_static_model :dog_kind, Breed
    end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/static_models.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

