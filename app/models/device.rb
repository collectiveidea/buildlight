class Device < ActiveRecord::Base
  validates :identifier, uniqueness: true, presence: true
end
