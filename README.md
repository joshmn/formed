<div align="center">
  <img width="450" src="https://github.com/joshmn/formed/raw/master/logo.png" alt="Formed logo" />
</div>

<div align="center">
    <a href="https://codecov.io/gh/joshmn/formed">
        <img src="https://codecov.io/gh/joshmn/formed/branch/master/graph/badge.svg?token=5LCOB4ESHL" alt="Coverage"/>
    </a>
    <a href="https://codeclimate.com/github/joshmn/formed/maintainability">
        <img src="https://api.codeclimate.com/v1/badges/9c075416ce74985d5c6c/maintainability" alt="Maintainability"/>
    </a>
</div>


# Formed

Formed is the form object pattern you never knew you needed: uses ActiveModel under the hood, and supports associations just like ActiveRecord.

## Contents

* [Usage](#usage)
* [Installation](*installation)
* [Acknowledgements](*acknowledgements)
* [Contributing](*contribuing)

## Usage

Formed form objects act just like the ActiveRecord models you started forcing into form helpers.

### Basic form 

```ruby
class ProductForm < Formed::Base 
  acts_like_model :product 
  
  attribute :title 
  attribute :content, :text 
end
```

### With validations

Use all the validations your heart desires.

```ruby
class PostForm < Formed::Base 
  acts_like_model :post 
  
  attribute :title  
  attribute :content, :text 
  
  validates :title, presence: true 
  validates :content, presence: true 
end
```

### Associations

Here's the big one:

```ruby
class TicketForm < Formed::Base 
  acts_like_model :ticket 
  
  attribute :name

  # automatically applies accepts_nested_attributes_for
  has_many :ticket_prices, class_name: "TicketPriceForm"

  validates :name, presence: true  
end
```

```ruby
class TicketPriceForm < Formed::Base
  acts_like_model :ticket_price

  attribute :price_in_cents, :integer

  validates :price_in_cents, presence: true, numericality: { greater_than: 0 }
end
```

### Context

Add context:

```ruby
class OrganizationForm < Formed::Base 
  acts_like_model :organization 
  
  attribute :location_id, :integer 
  
  def location_id_options
    context.organization.locations
  end
end
```

```ruby
form = OrganizationForm.new
form.with_context(organization: @organization)
```

Context gets passed down to all associations too.

```ruby
class OrganizationForm < Formed::Base 
  acts_like_model :organization 
  
  has_many :users, class_name: "UserForm"
  
  attribute :location_id, :integer 
  
  def location_id_options
    context.organization.locations
  end
end
```

```ruby
form = OrganizationForm.new 
form.with_context(organization: @organization)
user = form.users.new
user.context == form.context # true 
```

## Suggestions

### Let forms be forms, not forms with actions

Forms should only know do one thing: represent a form and the form's state. Leave logic to its own.

If you use something like ActiveDuty, you could do this:

```ruby
class MyCommand < ApplicationCommand
  def initialize(form)
    @form = form 
  end
  
  def call
    return broadcast(:invalid, form) unless @form.valid? 
    
    # ...
  end
end
```

## Contributing

By submitting a Pull Request, you disavow any rights or claims to any changes submitted to the Formed project and assign the copyright of those changes to joshmn.

If you cannot or do not want to reassign those rights (your employment contract for your employer may not allow this), you should not submit a PR. Open an issue and someone else can do the work.

This is a legal way of saying "If you submit a PR to us, that code becomes ours". 99.99% of the time that's what you intend anyways; we hope it doesn't scare you away from contributing.

## Acknowledgements

This was heavily inspired by — and tries to be backwards compatible with — AndyPike's Rectify form pattern.  
