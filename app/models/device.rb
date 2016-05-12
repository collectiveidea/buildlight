class Device < ActiveRecord::Base
  validates :name, presence: true
  validates :identifier, uniqueness: true, presence: true
end
