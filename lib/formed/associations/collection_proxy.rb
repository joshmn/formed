# frozen_string_literal: true

module Formed
  module Associations
    class CollectionProxy < Relation
      def initialize(klass, association, **) # :nodoc:
        @association = association
        super klass

        extensions = association.extensions
        extend(*extensions) if extensions.any?
      end

      def target
        @association.target
      end

      def load_target
        @association.load_target
      end

      # Returns +true+ if the association has been loaded, otherwise +false+.
      #
      #   person.pets.loaded? # => false
      #   person.pets.records
      #   person.pets.loaded? # => true
      def loaded?
        @association.loaded?
      end
      alias loaded loaded?

      def last(limit = nil)
        if limit
          target.last(limit)
        else
          target.last
        end
      end

      # Gives a record (or N records if a parameter is supplied) from the collection
      # using the same rules as <tt>ActiveRecord::Base.take</tt>.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.take # => #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>
      #
      #   person.pets.take(2)
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>
      #   #    ]
      #
      #   another_person_without.pets         # => []
      #   another_person_without.pets.take    # => nil
      #   another_person_without.pets.take(2) # => []
      def take(limit = nil)
        target.take(limit)
      end

      # Returns a new object of the collection type that has been instantiated
      # with +attributes+ and linked to this object, but have not yet been saved.
      # You can pass an array of attributes hashes, this will return an array
      # with the new objects.
      #
      #   class Person
      #     has_many :pets
      #   end
      #
      #   person.pets.build
      #   # => #<Pet id: nil, name: nil, person_id: 1>
      #
      #   person.pets.build(name: 'Fancy-Fancy')
      #   # => #<Pet id: nil, name: "Fancy-Fancy", person_id: 1>
      #
      #   person.pets.build([{name: 'Spook'}, {name: 'Choo-Choo'}, {name: 'Brain'}])
      #   # => [
      #   #      #<Pet id: nil, name: "Spook", person_id: 1>,
      #   #      #<Pet id: nil, name: "Choo-Choo", person_id: 1>,
      #   #      #<Pet id: nil, name: "Brain", person_id: 1>
      #   #    ]
      #
      #   person.pets.size  # => 5 # size of the collection
      #   person.pets.count # => 0 # count from database
      def build(attributes = {}, &block)
        @association.build(attributes, &block)
      end
      alias new build

      def with_context(context)
        each { |record| record.with_context(context) }
      end

      # Replaces this collection with +other_array+. This will perform a diff
      # and delete/add only records that have changed.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [#<Pet id: 1, name: "Gorby", group: "cats", person_id: 1>]
      #
      #   other_pets = [Pet.new(name: 'Puff', group: 'celebrities')]
      #
      #   person.pets.replace(other_pets)
      #
      #   person.pets
      #   # => [#<Pet id: 2, name: "Puff", group: "celebrities", person_id: 1>]
      #
      # If the supplied array has an incorrect association type, it raises
      # an <tt>ActiveRecord::AssociationTypeMismatch</tt> error:
      #
      #   person.pets.replace(["doo", "ggie", "gaga"])
      #   # => ActiveRecord::AssociationTypeMismatch: Pet expected, got String
      def replace(other_array)
        @association.replace(other_array)
      end

      ##
      # :method: count
      #
      # :call-seq:
      #   count(column_name = nil, &block)
      #
      # Count all records.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   # This will perform the count using SQL.
      #   person.pets.count # => 3
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      # Passing a block will select all of a person's pets in SQL and then
      # perform the count using Ruby.
      #
      #   person.pets.count { |pet| pet.name.include?('-') } # => 2

      # Returns the size of the collection. If the collection hasn't been loaded,
      # it executes a <tt>SELECT COUNT(*)</tt> query. Else it calls <tt>collection.size</tt>.
      #
      # If the collection has been already loaded +size+ and +length+ are
      # equivalent. If not and you are going to need the records anyway
      # +length+ will take one less query. Otherwise +size+ is more efficient.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.size # => 3
      #   # executes something like SELECT COUNT(*) FROM "pets" WHERE "pets"."person_id" = 1
      #
      #   person.pets # This will execute a SELECT * FROM query
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      #
      #   person.pets.size # => 3
      #   # Because the collection is already loaded, this will behave like
      #   # collection.size and no SQL count query is executed.
      def size
        @association.size
      end

      ##
      # :method: length
      #
      # :call-seq:
      #   length()
      #
      # Returns the size of the collection calling +size+ on the target.
      # If the collection has been already loaded, +length+ and +size+ are
      # equivalent. If not and you are going to need the records anyway this
      # method will take one less query. Otherwise +size+ is more efficient.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.length # => 3
      #   # executes something like SELECT "pets".* FROM "pets" WHERE "pets"."person_id" = 1
      #
      #   # Because the collection is loaded, you can
      #   # call the collection with no additional queries:
      #   person.pets
      #   # => [
      #   #       #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #       #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #       #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]

      # Returns +true+ if the collection is empty. If the collection has been
      # loaded it is equivalent
      # to <tt>collection.size.zero?</tt>. If the collection has not been loaded,
      # it is equivalent to <tt>!collection.exists?</tt>. If the collection has
      # not already been loaded and you are going to fetch the records anyway it
      # is better to check <tt>collection.load.empty?</tt>.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count  # => 1
      #   person.pets.empty? # => false
      #
      #   person.pets.delete_all
      #
      #   person.pets.count  # => 0
      #   person.pets.empty? # => true
      def empty?
        @association.empty?
      end

      ##
      # :method: any?
      #
      # :call-seq:
      #   any?()
      #
      # Returns +true+ if the collection is not empty.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count # => 0
      #   person.pets.any?  # => false
      #
      #   person.pets << Pet.new(name: 'Snoop')
      #   person.pets.count # => 1
      #   person.pets.any?  # => true
      #
      # Calling it without a block when the collection is not yet
      # loaded is equivalent to <tt>collection.exists?</tt>.
      # If you're going to load the collection anyway, it is better
      # to call <tt>collection.load.any?</tt> to avoid an extra query.
      #
      # You can also pass a +block+ to define criteria. The behavior
      # is the same, it returns true if the collection based on the
      # criteria is not empty.
      #
      #   person.pets
      #   # => [#<Pet name: "Snoop", group: "dogs">]
      #
      #   person.pets.any? do |pet|
      #     pet.group == 'cats'
      #   end
      #   # => false
      #
      #   person.pets.any? do |pet|
      #     pet.group == 'dogs'
      #   end
      #   # => true

      ##
      # :method: many?
      #
      # :call-seq:
      #   many?()
      #
      # Returns true if the collection has more than one record.
      # Equivalent to <tt>collection.size > 1</tt>.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.count # => 1
      #   person.pets.many? # => false
      #
      #   person.pets << Pet.new(name: 'Snoopy')
      #   person.pets.count # => 2
      #   person.pets.many? # => true
      #
      # You can also pass a +block+ to define criteria. The
      # behavior is the same, it returns true if the collection
      # based on the criteria has more than one record.
      #
      #   person.pets
      #   # => [
      #   #      #<Pet name: "Gorby", group: "cats">,
      #   #      #<Pet name: "Puff", group: "cats">,
      #   #      #<Pet name: "Snoop", group: "dogs">
      #   #    ]
      #
      #   person.pets.many? do |pet|
      #     pet.group == 'dogs'
      #   end
      #   # => false
      #
      #   person.pets.many? do |pet|
      #     pet.group == 'cats'
      #   end
      #   # => true

      # Returns +true+ if the given +record+ is present in the collection.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets # => [#<Pet id: 20, name: "Snoop">]
      #
      #   person.pets.include?(Pet.find(20)) # => true
      #   person.pets.include?(Pet.find(21)) # => false
      def include?(record)
        !!@association.include?(record)
      end

      def proxy_association # :nodoc:
        @association
      end

      # Returns a <tt>Relation</tt> object for the records in this association
      def scope
        @scope ||= @association.scope
      end

      # Equivalent to <tt>Array#==</tt>. Returns +true+ if the two arrays
      # contain the same number of elements and if each element is equal
      # to the corresponding element in the +other+ array, otherwise returns
      # +false+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>
      #   #    ]
      #
      #   other = person.pets.to_ary
      #
      #   person.pets == other
      #   # => true
      #
      #   other = [Pet.new(id: 1), Pet.new(id: 2)]
      #
      #   person.pets == other
      #   # => false
      def ==(other)
        load_target == other
      end

      ##
      # :method: to_ary
      #
      # :call-seq:
      #   to_ary()
      #
      # Returns a new array of objects from the collection. If the collection
      # hasn't been loaded, it fetches the records from the database.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets
      #   # => [
      #   #       #<Pet id: 4, name: "Benny", person_id: 1>,
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]
      #
      #   other_pets = person.pets.to_ary
      #   # => [
      #   #       #<Pet id: 4, name: "Benny", person_id: 1>,
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]
      #
      #   other_pets.replace([Pet.new(name: 'BooGoo')])
      #
      #   other_pets
      #   # => [#<Pet id: nil, name: "BooGoo", person_id: 1>]
      #
      #   person.pets
      #   # This is not affected by replace
      #   # => [
      #   #       #<Pet id: 4, name: "Benny", person_id: 1>,
      #   #       #<Pet id: 5, name: "Brain", person_id: 1>,
      #   #       #<Pet id: 6, name: "Boss",  person_id: 1>
      #   #    ]

      def records # :nodoc:
        load_target
      end

      # Adds one or more +records+ to the collection by setting their foreign keys
      # to the association's primary key. Since <tt><<</tt> flattens its argument list and
      # inserts each record, +push+ and +concat+ behave identically. Returns +self+
      # so several appends may be chained together.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets.size # => 0
      #   person.pets << Pet.new(name: 'Fancy-Fancy')
      #   person.pets << [Pet.new(name: 'Spook'), Pet.new(name: 'Choo-Choo')]
      #   person.pets.size # => 3
      #
      #   person.id # => 1
      #   person.pets
      #   # => [
      #   #      #<Pet id: 1, name: "Fancy-Fancy", person_id: 1>,
      #   #      #<Pet id: 2, name: "Spook", person_id: 1>,
      #   #      #<Pet id: 3, name: "Choo-Choo", person_id: 1>
      #   #    ]
      def <<(*records)
        proxy_association.concat(records) && self
      end
      alias push <<
      alias append <<
      alias concat <<

      def prepend(*_args) # :nodoc:
        raise NoMethodError, "prepend on association is not defined. Please use <<, push or append"
      end

      # Equivalent to +delete_all+. The difference is that returns +self+, instead
      # of an array with the deleted objects, so methods can be chained. See
      # +delete_all+ for more information.
      # Note that because +delete_all+ removes records by directly
      # running an SQL query into the database, the +updated_at+ column of
      # the object is not changed.
      def clear
        delete_all
        self
      end

      # Reloads the collection from the database. Returns +self+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets # uses the pets cache
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets.reload # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      def reload
        proxy_association.reload(true)
        reset_scope
      end

      # Unloads the association. Returns +self+.
      #
      #   class Person < ActiveRecord::Base
      #     has_many :pets
      #   end
      #
      #   person.pets # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets # uses the pets cache
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      #
      #   person.pets.reset # clears the pets cache
      #
      #   person.pets  # fetches pets from the database
      #   # => [#<Pet id: 1, name: "Snoop", group: "dogs", person_id: 1>]
      def reset
      end

      def reset_scope # :nodoc:
        self
      end

      def inspect # :nodoc:
        load_target if find_from_target?
        super
      end

      private

      def find_from_target?
        @association.find_from_target?
      end

    end
  end
end
