require 'sinatra/base'
require 'sinatra/contrib/all'
require 'sqlite3'

class BaltoConsultation < Sinatra::Base
  enable :sessions
  attr_accessor :pet, :pet_name, :sex, :breed, :k1, :age_years, :age_months, :age_total_months, :lifestage, :neuter, :k3, :body_condition, :nec, :weight_current, :weight_adult, :weight_target, :activity_level, :k2, :stimulation, :food_type, :food_brand, :ingredient_exclusion, :dental_brushing, :dental_chews, :wellness_issues, :email, :age_adult_months, :age_senior_years, :mer, :diet_mix

  #Initialize variables to store user's answers
    @pet = ""
    @pet_name = ""
    @sex = ""
    @breed = ""
    #@k1 is a breed adjustment factor, that we use to calculate the pet's daily caloric needs (session[:mer]). This information is stored in our dog breeds databse
    @k1 = ""
    @age_years = 0
    @age_months = 0
    @age_total_months = 0
    @lifestage = ""
    @neuter = ""
    #@k3 is a neutered adjustment factor, that we use to calculate the pet's daily caloric needs (session[:mer]). This information is stored in our dog breeds databse
    @k3 = 0
    @body_condition = ""
    @nec = 0
    @weight_current = 0
    @weight_adult = 0
    @weight_target = 0
    @activity_level = ""
    #@k2 is an activity level adjustment factor, that we use to calculate the pet's daily caloric needs (session[:mer]). This information is stored in our dog breeds databse
    @k2 = 0
    @stimulation = ""
    @food_type = ""
    @food_brand = ""
    @ingredient_exclusion = ""
    @dental_brushing = ""
    @dental_chews = ""
    @wellness_issues = ""
    @email = ""
    @mer = 0
    @diet_mix = []

  get '/' do
    @pet = session[:pet]
    erb :index
  end

  post '/' do
    session[:pet] = params[:pet]
    if session[:pet] == "dog"
      redirect '/pet_name'
    else
      # proceed with cat branch questions
    end
  end

  get '/pet_name' do
    erb :pet_name
  end  

  post '/pet_name' do
    session[:pet_name] = params[:pet_name]
    redirect '/sex'
  end
  
  get '/sex' do
    erb :sex, locals: { pet_name: session[:pet_name] }
  end

  post '/sex' do
    session[:sex] = params[:sex]
    redirect '/breed'
  end

  get '/breed' do
    db = SQLite3::Database.new 'balto.db'
    breeds = db.execute("SELECT name FROM dog_breeds").flatten
    db.close
    erb :breed, locals: {breeds: breeds, pet_name: session[:pet_name]}
  end

  post '/breed' do
    session[:breed] = params[:breed]
    if params[:breed] == "Unknown breed"
      redirect '/age_unknown_breed'
    else
      # Retrieve the age of adulthood and seniority for the selected breed from the database
      db = SQLite3::Database.new 'balto.db'
      age_adult_months = db.execute("SELECT age_adult_months FROM dog_breeds WHERE name=?", [session[:breed]]).first
      age_senior_years = db.execute("SELECT age_senior_years FROM dog_breeds WHERE name=?", [session[:breed]]).first
      k1 = db.execute("SELECT k1 FROM dog_breeds WHERE name=?", [session[:breed]]).first
      db.close
      session[:age_adult_months] = age_adult_months[0].to_i
      session[:age_senior_years] = age_senior_years[0].to_i
      session[:k1] = k1[0].to_f
      redirect '/age'
    end
  end 

  get '/api/breed_tip' do
    db = SQLite3::Database.new 'balto.db'
    @breed = params[:breed]
    tip = db.execute("SELECT tip FROM dog_breeds WHERE name=?", [@breed]).first
    db.close
    content_type :json
    {tip: tip[0]}.to_json
  end

  get '/age_unknown_breed' do
    erb :age_unknown_breed, locals: { pet_name: session[:pet_name] }
  end

  post '/age_unknown_breed' do
    session[:lifestage] = params[:lifestage]
    session[:age_years] = params[:age_years]
    session[:age_months] = params[:age_months]
    session[:age_total_months] = (session[:age_years].to_i * 12) + session[:age_months].to_i
    redirect '/neuter'
  end

  get '/age' do
    erb :age, locals: { pet_name: session[:pet_name] }
  end

  # We will need to set up a Cron job on Vercel that recalculates age of the pet every month (this impacts the lifestage calc)
  post '/age' do
    session[:age_years] = params[:age_years]
    session[:age_months] = params[:age_months]
    # convert years to months and add to months
    session[:age_total_months] = (session[:age_years].to_i * 12) + session[:age_months].to_i

    # check if age is lesser than age of adulthood
    if session[:age_total_months].to_i < session[:age_adult_months]
      session[:lifestage] = "puppy"
    # check if age is greater than or equal to senior age for the breed
    elsif session[:age_years].to_i >= session[:age_senior_years]
      session[:lifestage] = "senior"

    # otherwise, lifestage is adult
    else
      session[:lifestage] = "adult"
    end
    
    redirect '/neuter'
  end

  get '/neuter' do
    erb :neuter, locals: { pet_name: session[:pet_name] }
  end

  post '/neuter' do
    neuter = params[:neuter]
    if neuter == "yes"
      session[:neuter] = "neutered"
      session[:k3] = 0.8
    else
      session[:neuter] = "not neutered"
      session[:k3] = 1
    end
    redirect '/body_condition'
  end

  get '/body_condition' do
    erb :body_condition, locals: { pet_name: session[:pet_name] }
  end

  post '/body_condition' do
    session[:body_condition] = params[:body_condition]
    if session[:body_condition] == "skinny"
      session[:nec] = 3
    elsif session[:body_condition] == "perfect"
      session[:nec] = 5
    else
      session[:nec] = 7
    end
    redirect '/weight_current'
  end  

  get '/weight_current' do
    erb :weight_current, locals: { pet_name: session[:pet_name], nec: session[:nec], lifestage: session[:lifestage] }
  end

  post '/weight_current' do
    session[:weight_current] = params[:weight].to_f
    if session[:nec] == 5
      session[:weight_target] = session[:weight_current] 
      redirect '/activity_level'  
    else
      redirect '/weight_specific'
    end
  end
  
  get '/weight_specific' do
    erb :weight_specific, locals: { pet_name: session[:pet_name], lifestage: session[:lifestage], breed: session[:breed], nec: session[:nec] }
  end

post '/weight_specific' do
  if session[:lifestage] == "puppy"
    session[:weight_adult] = params[:weight_adult]
      if session[:breed] != "Unknown breed"
        if session[:weight_adult] == "Unknown"
          # Recalls dog adult weight depending on sex from breeds DB
          db = SQLite3::Database.new 'balto.db'
            if session[:sex] == "male" 
              weight_adult = db.execute("SELECT weight_adult_male FROM dog_breeds WHERE name=?", [session[:breed]]).first
            else
              weight_adult = db.execute("SELECT weight_adult_female FROM dog_breeds WHERE name=?", [session[:breed]]).first
            end
          db.close
          session[:weight_adult] = weight_adult[0].to_i
        else
          session[:weight_adult] = params[:weight_adult].to_i
        end
      else
        session[:weight_adult] = params[:weight_adult].to_i
      end
  elsif session[:nec] != 5
    if params[:weight_target] == "Unknown"
      session[:weight_target] = (session[:weight_current].to_f * (100 / (100 + ((session[:nec].to_f - 5 ) * 10)))).round
    else 
      session[:weight_target] = params[:weight_target].to_i
    end
  redirect '/activity_level'
  end
end

  get '/activity_level' do
    erb :activity_level, locals: { pet_name: session[:pet_name] }
  end

  post '/activity_level' do
    activity_level = params[:activity_level]
    session[:stimulation] = params[:stimulation]
    if activity_level == "Lazy"
      session[:k2] = 0.8
    elsif activity_level == "Normal"
      session[:k2] = 0.9
    else
      session[:k2] = 1.1
    end
    session[:activity_level] = activity_level
    redirect '/food'
  end

  get '/food' do
    db = SQLite3::Database.new 'balto.db'
    food_brands = db.execute("SELECT name FROM food_brands").flatten
    db.close
    erb :food, locals: {food_brands: food_brands, pet_name: session[:pet_name]}
  end
    
  post '/food' do
    session[:food_type] = params[:food_type]
    session[:food_brand] = params[:food_brand]

    if session[:food_brand] != "Unknown brand"
      db = SQLite3::Database.new 'balto.db'
      brand_score = db.execute("SELECT scoring FROM food_brands WHERE name=?", session[:food_brand]).first
      db.close
      session[:food_brand_score] = brand_score[0].to_i
    end
  
    redirect '/ingredient_exclusion'
  end  
  

get '/ingredient_exclusion' do
  erb :ingredient_exclusion, locals: { pet_name: session[:pet_name] }
end

post '/ingredient_exclusion' do
  session[:ingredient_exclusion] = params[:ingredient_exclusion]
  redirect '/dental_care'
end

get '/dental_care' do
  erb :dental_care, locals: { pet_name: session[:pet_name] }
end

post '/dental_care' do
  session[:dental_brushing] = params[:dental_brushing]
  session[:dental_chews] = params[:dental_chews]
  redirect '/issues'
  end

  get '/issues' do
    db = SQLite3::Database.new 'balto.db'
    issues = db.execute("SELECT issue_name FROM wellness_issues").flatten
    db.close
    erb :issues, locals: {issues: issues, pet_name: session[:pet_name]}
  end
    
    post '/issues' do
    session[:wellness_issues] = params[:issues]
    redirect '/email'
    end

    get '/email' do
      erb :email, locals: {pet_name: session[:pet_name]}
    end
    
    post '/email' do
      session[:email] = params[:email]

      # Calcs - Pet caloric needs 
      if session[:pet] == "dog"
        if session[:lifestage] != "puppy" 
          session[:mer] = ((session[:weight_target].to_f ** 0.75) * 130 * session[:k2].to_f * session[:k3].to_f).round
        else
          session[:mer] = ((254 - (135 * session[:weight_current].to_f / session[:weight_adult].to_f)) * (session[:weight_current].to_f ** 0.75)).round
        end
      end

      # Determine diet mix
      def determine_diet_mix(food_type)
        if food_type.all? { |type| type == "Dry food" }
          diet_mix = {"dry" => "100%", "wet" => "0%"}
        else
          diet_mix = {"dry" => "75%", "wet" => "25%"}
        end
        return diet_mix
      end
      session[:diet_mix] = determine_diet_mix(session[:food_type])
    
    
      # Product recommendation function
      def determine_product_recommendations(diet_mix, lifestage, weight_current, nec, ingredient_exclusion)
        product_recommendations = {}
        db = SQLite3::Database.open "balto.db"
      
        # Convert ingredient_exclusion to an array of lowercase strings
        ingredient_exclusion = ingredient_exclusion.map{|ingredient| ingredient.downcase}.join(",").split(",")
      
        # Determine dry food product recommendations
        if diet_mix.include?("dry")
          dry_recommendations = []
          if lifestage == "puppy"
            if weight_current < 5
              dry_recommendations << "SGF"
            else
              dry_recommendations += ["PES", "AES", "SES"]
            end
          elsif lifestage == "senior" || nec == 7
            dry_recommendations += ["DES", "PES", "AES", "SES"]
          else
            dry_recommendations += ["PES", "AES", "SES"]
          end
        end
          # Exclude products that contain ingredients in ingredient_exclusion
          ingredient_exclusion = ingredient_exclusion.map{|ingredient| ingredient.downcase}.join(",").split(",")
          dry_recommendations.each do |product_id|
            protein_sources = db.execute("SELECT protein_sources FROM products WHERE product_ID = ? LIMIT 1", product_id)[0][0].to_s.split(",").map(&:downcase)
            if (protein_sources & ingredient_exclusion).empty?
              product_recommendations["dry"] ||= []
              product_recommendations["dry"] << product_id
            end
          end
  
        # Determine wet food product recommendations
        if diet_mix.include?("wet") && diet_mix["wet"] != "0%"
          wet_recommendations = []
          wet_recommendations << "DWR"
        # Exclude products that contain ingredients in ingredient_exclusion
          ingredient_exclusion = ingredient_exclusion.map{|ingredient| ingredient.downcase}.join(",").split(",")
          wet_recommendations.each do |product_id|
            protein_sources = db.execute("SELECT protein_sources FROM products WHERE product_ID = ? LIMIT 1", product_id)[0][0].to_s.split(",").map(&:downcase)
            if (protein_sources & ingredient_exclusion).empty?
              product_recommendations["wet"] ||= []
              product_recommendations["wet"] << product_id
            end
          end
        end
        return product_recommendations
      end
      
      session[:product_recommendations] = determine_product_recommendations(session[:diet_mix], session[:lifestage], session[:weight_current], session[:nec], session[:ingredient_exclusion])
      

      # Split MER depending on diet mix
      session[:daily_feeding_calories] = {}
      session[:diet_mix].each do |key, value|
        if key == "wet" && value == "0%"
          next
        end
        session[:daily_feeding_calories][key] = (session[:mer] * (value.to_f / 100)).to_i
      end

      # Calculate feeding amount for selected products 
      session[:daily_feeding_grams] = {}
        # Check product ID caloric density on the DB
      db = SQLite3::Database.open "balto.db"
      session[:product_recommendations].each do |key, value|
        product_id = value.first
        caloric_density = db.execute("SELECT caloric_density FROM products WHERE product_ID = ? LIMIT 1", product_id)[0][0]
        session[:daily_feeding_grams][key] = (session[:daily_feeding_calories][key] / caloric_density).to_i
      end
      
        # Pet profile work
        # Define the pet_profile_tags variable (array)
        pet_profile_tags = []
        # Add profile values to the array based on conditions
        pet_profile_tags << session[:lifestage]
        pet_profile_tags << session[:neuter]
        if session[:wellness_issues].include?("Mobility")
          pet_profile_tags << "mobility_issues"
        elsif session[:wellness_issues].include?("Digestion issues")
          pet_profile_tags << "digestion"
        end
        if session[:activity_level] == "lazy"
          pet_profile_tags << "activity_low"
        elsif session[:activity_level] = "normal"
          pet_profile_tags << "activity_normal"
        else
          pet_profile_tags << "activity_active"
        end
        if session[:nec] == 3
          pet_profile_tags << "underweight"
        elsif session[:nec] == 5
          pet_profile_tags << "weight_ideal"
        else 
          pet_profile_tags << "overweight"
        end
        session[:pet_profile_tags] = pet_profile_tags
        
        # Assign pet tips
        pet_tips = {
          nutrition: [],
          activity_body: [],
          skin_coat: [],
          dental: [],
          mental: []
          }

        # Query the pet_tips table
        db = SQLite3::Database.open "balto.db"
        rows = db.execute("SELECT * FROM pet_tips")

        # Get the column names
        column_names = db.execute("PRAGMA table_info(pet_tips)").map { |column| column[1] }
        
        # Get the index of the C1_inclusion, C2_inclusion and C3_exclusion columns
        c1_inclusion_index = column_names.index("C1_inclusion")
        c2_inclusion_index = column_names.index("C2_inclusion")
        c3_exclusion_index = column_names.index("C3_exclusion")
        axis_index = column_names.index("Axis")
        tip_tier_index = column_names.index("tip_tier")
        tip_id_index = column_names.index("ID")
        
        # Iterate through each row of the table to identify rows that match the C1_inclusion and C2_inclusion and don't match the C3_exclusion
        rows.each do |row|
          if (session[:pet_profile_tags].include?(row[c1_inclusion_index]) &&
            session[:pet_profile_tags].include?(row[c2_inclusion_index]) &&
            !session[:pet_profile_tags].include?(row[c3_exclusion_index]))
            
            # If the row matches, check if pet_tips already contains any ID that has the same C1_inclusion value as the one from the row currently being looped
            axis_value = row[axis_index]
            tip_tier_value = row[tip_tier_index]
            tip_id_value = row[tip_id_index]
            
            # Check if pet_tips already contains a tip with the same tip tier for the same axis
            if pet_tips[axis_value.to_sym].include?(tip_tier_value)
              next
            else
              pet_tips[axis_value.to_sym] << tip_id_value
            end
          end
        end

        # Iterate through each row of the table to identify rows that match only the C1_inclusion and don't match the C3_exclusion
        rows.each do |row|
          if (session[:pet_profile_tags].include?(row[c1_inclusion_index]) &&
            (row[c2_inclusion_index] == "null" || row[c2_inclusion_index].nil?) &&
            !session[:pet_profile_tags].include?(row[c3_exclusion_index]))
            
            # If the row matches, check if pet_tips already contains any ID that has the same C1_inclusion value as the one from the row currently being looped
            axis_value = row[axis_index]
            tip_tier_value = row[tip_tier_index]
            tip_id_value = row[tip_id_index]
            
            # Check if pet_tips already contains a tip with the same tip tier for the same axis
            if pet_tips[axis_value.to_sym].include?(tip_tier_value)
              next
            else
              pet_tips[axis_value.to_sym] << tip_id_value
            end
          end
        end

        session[:pet_tips] = pet_tips
        db.close

        # Create an array to store the tip IDs
        tip_ids = []
        # Add the tip IDs for each axis to the tip_ids array
        tip_ids = session[:pet_tips].values.flatten
        session[:tip_ids] = tip_ids

      redirect '/dummy'
    end

  get '/dummy' do
    
    # Define spider chart scoring
    
      # Nutrition score logic
        # Food quality = 80% of the nutrition score
  
        # When kibble only or kibble + wet
        if session[:food_type].length == session[:food_type].count("Dry food") || (session[:food_type].length == session[:food_type].count("Dry food") + session[:food_type].count("Wet food"))
          if session[:food_brand] == "Unknown brand"
            # Default kibble score is 3/5 if no breed is provided
            dry_quality_score = 3
          else
            # Kibble score is dictated by food database when brand is known
            dry_quality_score = session[:food_brand_score]
          end
          food_quality_score = dry_quality_score.to_f * 0.8
        # When kibble + raw or home-cooked
        else
          if session[:food_brand] == "Unknown brand"
            dry_quality_score = 3
          else
            dry_quality_score = session[:food_brand_score]
          end
          # Assume Dry food brings 75% of MER, and give 5/5 score to the 25% provided by raw/ home-cooked
          food_quality_score = ((dry_quality_score.to_f * 0.75 ) + (5.0 * 0.25)) * 0.8
        end
        
        # Digestion issues = 10% of the nutrition score
        if session[:wellness_issues].include?("Digestion issues")
          food_digestion_score = 0
        else
          food_digestion_score = 5 * 0.1
        end

        # Hydration = 10% of the nutrition score
        if session[:food_type].length == session[:food_type].count("Dry food")
          food_hydration_score = 3 * 0.1
        else
          food_hydration_score = 5 * 0.1
        end

      # Define spider chart Nutrition score as the Maximum between the Sum of the Food quality + digestion + hydration, and 3.5 (minimum score)
      session[:spider_chart_nutrition] = [(food_quality_score + food_digestion_score + food_hydration_score).round(1),3.5].max

      # Dental logic
        # Dental brushing score
      if session[:dental_brushing] == "Less than once a month"
        dental_brushing_score = 1.0 * 0.5
      elsif session[:dental_brushing] == "Once a month"
        dental_brushing_score = 3.0 * 0.5
      else
        dental_brushing_score = 5.0 * 0.5
      end

        # Dental chews score
      if session[:dental_chews] == "No"
        dental_chewing_score = 1.0 * 0.5
      else
        dental_chewing_score = 5.0 * 0.5
      end

        # Dental condition reduces Dental score by 0.5
      if session[:wellness_issues].include?("Dental issues")
        dental_issues = -0.5
      else
        dental_issues = 0
      end

      # Dental score rescored from 3 to 5
      session[:spider_chart_dental] = [(dental_brushing_score + dental_chewing_score + dental_issues).round(1),3.5].max

      # Skin logic
      spider_chart_skin = 5
      case
      when session[:wellness_issues].include?("Demangeaisons regulières")
        spider_chart_skin -= 0.5
      when session[:wellness_issues].include?("Dermatite atopique / Eczema")
        spider_chart_skin -= 1
      when session[:wellness_issues].include?("Parasites")
        spider_chart_skin -= 0.5
      when session[:wellness_issues].include?("Poil très rêche ou terne")
        spider_chart_skin -= 0.5
      else
        spider_chart_skin = 5
      end
      session[:spider_chart_skin] = spider_chart_skin

      # Body and activity logic
      # Current body condition (50% of score)
      if session[:nec] != 5
        body_condition_score = 3.0 * 0.5
      else
        body_condition_score = 5.0 * 0.5
      end

      # Base activity level score (50% of score)
      case session[:activity_level]
      when "Lazy" 
        activity_level_score = 2.0 * 0.5
      when "Normal"
        activity_level_score = 4.0 * 0.5
      else
        activity_level_score = 5.0 * 0.5
      end

      # Mobility issues score adjustment
      mobility_issues_score = 0
      case
      when session[:wellness_issues].include?("Arthrose")
        mobility_issues_score -= 1 unless session[:activity_level] == "Lazy"
      when session[:wellness_issues].include?("Raideurs")
        mobility_issues_score -= 0.5 unless session[:activity_level] == "Lazy"
      when session[:wellness_issues].include?("Dysplasie")
        mobility_issues_score -= 1 unless session[:activity_level] == "Lazy"
      when session[:wellness_issues].include?("Opération affectant les articulations")
        mobility_issues_score -= 1 unless session[:activity_level] == "Lazy"
      else
        mobility_issues_score = 0
      end
        
      # Combine activity and mobility issues scores
      activity_level_score += mobility_issues_score

      # Dental score, rescored from 3.5 to 5
      session[:spider_chart_body] = [(body_condition_score + activity_level_score).round(1), 3.5].max

      # Mental stimulation logic
      # Base activity level score (50% of score)
      case session[:activity_level]
      when "Lazy" 
        activity_level_score = 2.0 * 0.5
      when "Normal"
        activity_level_score = 4.0 * 0.5
      else
        activity_level_score = 5.0 * 0.5
      end

      # Access to chewing (25% of score)
      if session[:dental_chews] == "No"
        dental_chewing_score = 1.0 * 0.25
      else
        dental_chewing_score = 5.0 * 0.25
      end

      # Engagement in stimulating activities (25% of score)
      case
      when session[:stimulation] == "Very rarely"
        stimulation_score = 1 * 0.25
      when session[:stimulation] == "Occasionally"
        stimulation_score = 2 * 0.25
      when session[:stimulation] == "Fairly often"
        stimulation_score = 4 * 0.25
      when session[:stimulation] == "Daily"
        stimulation_score = 5 * 0.25
      else
        stimulation_score = 5 * 0.25
      end

      # Mental health score adjustment
      mental_issues_score = 0
      case
      when session[:wellness_issues].include?("Anxiété de séparation")
        mental_issues_score -= 1
      when session[:wellness_issues].include?("Trouble obsessionnel compulsif")
        mental_issues_score -= 1
      when session[:wellness_issues].include?("Peur")
        mental_issues_score -= 1
      when session[:wellness_issues].include?("Agressivité")
        mental_issues_score -= 1
      when session[:wellness_issues].include?("Aboiements excessifs")
        mental_issues_score -= 1
      else
        mental_issues_score = 0
      end

      # Mental stimulation score, rescored from 3.5 to 5
      session[:spider_chart_mental] = [(activity_level_score + dental_chewing_score + stimulation_score + mental_issues_score).round(1), 3.5].max

    # Group pet tips by chart Axis and subgroups, and then pass them to front-end  
    
    # Connect to the database
    db = SQLite3::Database.new 'balto.db'

    # Get the tips stored in the session
    tip_ids = session[:tip_ids]
    pet_tips = session[:pet_tips]

    # Create an empty hash to store the tips grouped by axis and subgroup
    grouped_tips = {
      nutrition: {},
      activity_body: {},
      skin_coat: {},
      dental: {},
      mental: {}
    }

    # Get the information for each tip
    db.execute("SELECT ID, tip_tier, tip_subgroup, card_content FROM pet_tips WHERE ID IN (#{tip_ids.join(',')})").each do |row|
      tip_id, tip_tier, tip_subgroup, card_content = row[0], row[1], row[2], row[3]     
    
      # Determine the axis for the current tip
      axis = nil
      pet_tips.each do |a, tips|
        if tips.include?(tip_id)
          axis = a
          break
        end
      end

      # Group the tips by axis and subgroup
      if grouped_tips[axis][tip_subgroup].nil?
        grouped_tips[axis][tip_subgroup] = []
      end
      grouped_tips[axis][tip_subgroup] << { tip_tier: tip_tier, card_content: card_content }

      # Sort the tips within each subgroup by the tip tier
      grouped_tips.each do |axis, subgroups|
        subgroups.each do |subgroup, tips|
          grouped_tips[axis][subgroup].sort_by! { |tip| tip[:tip_tier] }
        end
      end
    session[:grouped_tips] = grouped_tips
    end

    erb :dummy, locals: {
      pet: session[:pet],
      pet_name: session[:pet_name],
      sex: session[:sex],
      breed: session[:breed],
      k1: session[:k1],
      age_years: session[:age_years],
      age_months: session[:age_months],
      age_total_months: session[:age_total_months],
      lifestage: session[:lifestage],
      neuter: session[:neuter],
      k3: session[:k3],
      body_condition: session[:body_condition],
      nec: session[:nec],
      weight_current: session[:weight_current],
      weight_adult: session[:weight_adult],
      weight_target: session[:weight_target],
      activity_level: session[:activity_level], 
      k2: session[:k2],
      stimulation: session[:stimulation],
      food_type: session[:food_type],
      food_brand: session[:food_brand],
      food_brand_score: session[:food_brand_score],
      ingredient_exclusion: session[:ingredient_exclusion],
      dental_brushing: session[:dental_brushing],
      dental_chews: session[:dental_chews],
      wellness_issues: session[:wellness_issues],
      email: session[:email],
      mer: session[:mer],
      diet_mix: session[:diet_mix],
      protein_sources: session[:protein_sources],
      product_recommendations: session[:product_recommendations],
      daily_feeding_calories: session[:daily_feeding_calories],
      daily_feeding_grams: session[:daily_feeding_grams],
      pet_profile_tags: session[:pet_profile_tags],
      pet_tips: session[:pet_tips],
      tip_ids: session[:tip_ids],
      grouped_tips: session[:grouped_tips],
      spider_chart_nutrition: session[:spider_chart_nutrition],
      spider_chart_dental: session[:spider_chart_dental],
      spider_chart_skin: session[:spider_chart_skin],
      spider_chart_body: session[:spider_chart_body],
      spider_chart_mental: session[:spider_chart_mental] }
  
  end

BaltoConsultation.run!
end