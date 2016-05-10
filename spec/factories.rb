FactoryGirl.define do
  factory :device do
    usernames []
    projects []
  end

  factory :status do
    sequence(:project_id)   {|i| i.to_s }
    sequence(:project_name) {|i| "buildlight#{i}" }
    red false
    yellow false
  end
end