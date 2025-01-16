params = {
  email: "mattius.taylor@gmail.com",
  password: "password",
  password_confirmation: "password",
  first_name: "Matt",
  last_name: "Taylor",
  username: "mathetrius",
  roles: ["owner"],
}
User.create!(**params)
