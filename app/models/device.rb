class Device < ApplicationRecord
  validates :name, presence: true
  validates :identifier, uniqueness: true, presence: true
end
