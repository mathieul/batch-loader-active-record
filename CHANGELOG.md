# Changelog

Unreleased

* none

v0.4.3

* fix dependency to activerecord and builds

v0.4.2

* fix to support activerecord v4.2.10 and test v4.2, v5.0, v5.1 and v5.2 using appraisal

v0.4.1

* fix cache issue when calling lazy association accessor with different scopes for `has_and_belongs_to` associations

v0.4.0

* support `has_and_belongs_to` associations

v0.3.1

* allow to decouple declaring the assocation with Active Record DSL and generate a lazy association accessor with `association_accessor`

v0.3.0

* allow to specify an association scope with `belongs_to_lazy`, `has_one_lazy` and `has_many_lazy`

v0.2.0

* allow to use `has_many_lazy` with `through: ...` option

v0.1.0

* initial release
* doens't support `has_and_belongs_to_lazy`
* doesn't support `has_many_lazy ... through: ...`
* doesn't support association scope
* doesn't support polymorphic associations