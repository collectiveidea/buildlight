FactoryBot.define do
  factory :device do
    usernames { [] }
    projects { [] }
    sequence(:name) { |i| "Device #{i}" }
    sequence(:slug) { |i| "slug-#{i}" }

    trait :with_identifier do
      sequence(:identifier) { |i| "device-#{i}" }
    end
  end

  factory :status do
    service { "travis" }
    sequence(:project_id, &:to_s)
    sequence(:project_name) { |i| "buildlight#{i}" }
    red { false }
    yellow { false }
  end
end
