Rails.application.routes.draw do
  # Modern platform HTTP (CommandTower::Engine.routes). Prefix "" keeps CT request
  # specs on raw paths; DFM mounts the same engine at "/api".
  mount CommandTower::Engine => "/"

  namespace :foundation_proof do
    post "echo", to: "echo#create"
  end
end
