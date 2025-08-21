function update_theme --on-variable background_mode
  if [ "$background_mode" = "dark" ]
    fish_config theme choose 'dark'
  else if [ "$background_mode" = "light" ]
    fish_config theme choose "Snow Day"
  end
end
