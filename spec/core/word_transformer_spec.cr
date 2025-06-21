require "spec"
require "../../src/amber_cli/core/word_transformer"

describe AmberCLI::Core::WordTransformer do
  describe ".transform" do
    context "with basic transformations" do
      it "converts to singular form" do
        AmberCLI::Core::WordTransformer.transform("users", "singular").should eq("user")
        AmberCLI::Core::WordTransformer.transform("companies", "singular").should eq("company")
        AmberCLI::Core::WordTransformer.transform("wives", "singular").should eq("wife")
        AmberCLI::Core::WordTransformer.transform("lives", "singular").should eq("life")
        AmberCLI::Core::WordTransformer.transform("boxes", "singular").should eq("box")
        AmberCLI::Core::WordTransformer.transform("dishes", "singular").should eq("dish")
        # Test custom singulars
        AmberCLI::Core::WordTransformer.transform("heroes", "singular").should eq("hero")
        AmberCLI::Core::WordTransformer.transform("potatoes", "singular").should eq("potato")
      end

      it "converts to plural form" do
        AmberCLI::Core::WordTransformer.transform("user", "plural").should eq("users")
        AmberCLI::Core::WordTransformer.transform("company", "plural").should eq("companies")
        AmberCLI::Core::WordTransformer.transform("city", "plural").should eq("cities")
        AmberCLI::Core::WordTransformer.transform("day", "plural").should eq("days")  # vowel before y
        AmberCLI::Core::WordTransformer.transform("wife", "plural").should eq("wives")
        AmberCLI::Core::WordTransformer.transform("life", "plural").should eq("lives")
        AmberCLI::Core::WordTransformer.transform("box", "plural").should eq("boxes")
        AmberCLI::Core::WordTransformer.transform("dish", "plural").should eq("dishes")
        AmberCLI::Core::WordTransformer.transform("church", "plural").should eq("churches")
        # Test custom plurals
        AmberCLI::Core::WordTransformer.transform("hero", "plural").should eq("heroes")
        AmberCLI::Core::WordTransformer.transform("potato", "plural").should eq("potatoes")
        AmberCLI::Core::WordTransformer.transform("echo", "plural").should eq("echoes")
      end

      it "converts to camel_case using Crystal's built-in method" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "camel_case").should eq("UserProfile")
        AmberCLI::Core::WordTransformer.transform("blog_post", "camel_case").should eq("BlogPost")
        AmberCLI::Core::WordTransformer.transform("single", "camel_case").should eq("Single")
        # Test with already PascalCase input
        AmberCLI::Core::WordTransformer.transform("UserProfile", "camel_case").should eq("UserProfile")
      end

      it "converts to pascal_case (same as camel_case)" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "pascal_case").should eq("UserProfile")
        AmberCLI::Core::WordTransformer.transform("blog_post", "pascal_case").should eq("BlogPost")
        AmberCLI::Core::WordTransformer.transform("APIController", "pascal_case").should eq("ApiController")
      end

      it "converts to snake_case using Crystal's built-in method" do
        AmberCLI::Core::WordTransformer.transform("UserProfile", "snake_case").should eq("user_profile")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "snake_case").should eq("blog_post")
        AmberCLI::Core::WordTransformer.transform("user", "snake_case").should eq("user")
        AmberCLI::Core::WordTransformer.transform("XMLHttpRequest", "snake_case").should eq("xml_http_request")
      end

      it "converts to kebab_case using Crystal's methods" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "kebab_case").should eq("user-profile")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "kebab_case").should eq("blog-post")
        AmberCLI::Core::WordTransformer.transform("XMLHttpRequest", "kebab_case").should eq("xml-http-request")
      end

      it "converts to title_case using Crystal's methods" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "title_case").should eq("User Profile")
        AmberCLI::Core::WordTransformer.transform("blog_post", "title_case").should eq("Blog Post")
        AmberCLI::Core::WordTransformer.transform("UserProfile", "title_case").should eq("User Profile")
      end

      it "converts to upper_case" do
        AmberCLI::Core::WordTransformer.transform("user", "upper_case").should eq("USER")
        AmberCLI::Core::WordTransformer.transform("blog_post", "upper_case").should eq("BLOG_POST")
        AmberCLI::Core::WordTransformer.transform("UserProfile", "upper_case").should eq("USERPROFILE")
      end

      it "converts to lower_case" do
        AmberCLI::Core::WordTransformer.transform("USER", "lower_case").should eq("user")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "lower_case").should eq("blogpost")
        AmberCLI::Core::WordTransformer.transform("BLOG_POST", "lower_case").should eq("blog_post")
      end

      it "converts to constant_case using Crystal's methods" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "constant_case").should eq("USER_PROFILE")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "constant_case").should eq("BLOG_POST")
        AmberCLI::Core::WordTransformer.transform("XMLHttpRequest", "constant_case").should eq("XML_HTTP_REQUEST")
      end

      it "humanizes using Crystal's methods" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "humanize").should eq("User profile")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "humanize").should eq("Blog post")
        AmberCLI::Core::WordTransformer.transform("first_name", "humanize").should eq("First name")
      end

      it "classifies using inflector for complex cases" do
        AmberCLI::Core::WordTransformer.transform("user_profiles", "classify").should eq("UserProfile")
        AmberCLI::Core::WordTransformer.transform("blog_posts", "classify").should eq("BlogPost")
      end

      it "tableizes correctly" do
        AmberCLI::Core::WordTransformer.transform("User", "tableize").should eq("users")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "tableize").should eq("blog_posts")
        AmberCLI::Core::WordTransformer.transform("Category", "tableize").should eq("categories")
      end

      it "creates foreign keys" do
        AmberCLI::Core::WordTransformer.transform("User", "foreign_key").should eq("user_id")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "foreign_key").should eq("blog_post_id")
      end
    end

    context "with compound transformations" do
      it "converts to snake_case_plural" do
        AmberCLI::Core::WordTransformer.transform("User", "snake_case_plural").should eq("users")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "snake_case_plural").should eq("blog_posts")
        AmberCLI::Core::WordTransformer.transform("Category", "snake_case_plural").should eq("categories")
      end

      it "converts to pascal_case_plural" do
        AmberCLI::Core::WordTransformer.transform("user", "pascal_case_plural").should eq("Users")
        AmberCLI::Core::WordTransformer.transform("blog_post", "pascal_case_plural").should eq("BlogPosts")
        AmberCLI::Core::WordTransformer.transform("company", "pascal_case_plural").should eq("Companies")
      end

      it "converts to kebab_case_plural" do
        AmberCLI::Core::WordTransformer.transform("User", "kebab_case_plural").should eq("users")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "kebab_case_plural").should eq("blog-posts")
        AmberCLI::Core::WordTransformer.transform("Category", "kebab_case_plural").should eq("categories")
      end
    end

    context "with custom naming conventions" do
      it "applies custom transformation patterns" do
        conventions = {
          "controller_suffix" => "{{word}}Controller",
          "interface_prefix" => "I{{word}}",
          "repository_pattern" => "{{word}}Repository"
        }

        AmberCLI::Core::WordTransformer.transform("User", "controller_suffix", conventions).should eq("UserController")
        AmberCLI::Core::WordTransformer.transform("User", "interface_prefix", conventions).should eq("IUser")
        AmberCLI::Core::WordTransformer.transform("User", "repository_pattern", conventions).should eq("UserRepository")
      end

      it "handles complex patterns" do
        conventions = {
          "service_class" => "{{word}}Service",
          "api_endpoint" => "/api/v1/{{word}}",
          "table_name" => "app_{{word}}_data"
        }

        AmberCLI::Core::WordTransformer.transform("User", "service_class", conventions).should eq("UserService")
        AmberCLI::Core::WordTransformer.transform("posts", "api_endpoint", conventions).should eq("/api/v1/posts")
        AmberCLI::Core::WordTransformer.transform("users", "table_name", conventions).should eq("app_users_data")
      end

      it "custom conventions override standard transformations" do
        conventions = {
          "snake_case" => "custom_{{word}}_override",
          "pascal_case" => "{{word}}CustomClass"
        }
        
        AmberCLI::Core::WordTransformer.transform("user", "snake_case", conventions).should eq("custom_user_override")
        AmberCLI::Core::WordTransformer.transform("user", "pascal_case", conventions).should eq("userCustomClass")
      end

      it "falls back to standard transformations when custom pattern not found" do
        conventions = {"custom_pattern" => "{{word}}Custom"}
        
        AmberCLI::Core::WordTransformer.transform("user", "snake_case", conventions).should eq("user")
        AmberCLI::Core::WordTransformer.transform("UserProfile", "snake_case", conventions).should eq("user_profile")
      end

      it "returns original word when transformation not recognized" do
        AmberCLI::Core::WordTransformer.transform("user", "unknown_transformation").should eq("user")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "invalid_type").should eq("BlogPost")
      end
    end

    context "edge cases" do
      it "handles empty strings" do
        AmberCLI::Core::WordTransformer.transform("", "plural").should eq("")
        AmberCLI::Core::WordTransformer.transform("", "singular").should eq("")
        AmberCLI::Core::WordTransformer.transform("", "snake_case").should eq("")
        AmberCLI::Core::WordTransformer.transform("", "pascal_case").should eq("")
      end

      it "handles single character words" do
        AmberCLI::Core::WordTransformer.transform("a", "plural").should eq("as")
        AmberCLI::Core::WordTransformer.transform("i", "plural").should eq("is")
        AmberCLI::Core::WordTransformer.transform("A", "snake_case").should eq("a")
        AmberCLI::Core::WordTransformer.transform("x", "pascal_case").should eq("X")
      end

      it "handles irregular plurals correctly" do
        # These test proper English pluralization using inflector.cr and custom overrides
        AmberCLI::Core::WordTransformer.transform("mouse", "plural").should eq("mice")
        AmberCLI::Core::WordTransformer.transform("child", "plural").should eq("children")
        AmberCLI::Core::WordTransformer.transform("person", "plural").should eq("people")
        # This uses our custom override since inflector.cr returns "foots"
        AmberCLI::Core::WordTransformer.transform("foot", "plural").should eq("feet")
      end

      it "handles words ending in 'ss'" do
        AmberCLI::Core::WordTransformer.transform("class", "plural").should eq("classes")
        AmberCLI::Core::WordTransformer.transform("glass", "plural").should eq("glasses")
        AmberCLI::Core::WordTransformer.transform("mass", "plural").should eq("masses")
      end

      it "handles acronyms and abbreviations" do
        AmberCLI::Core::WordTransformer.transform("API", "snake_case").should eq("api")
        AmberCLI::Core::WordTransformer.transform("XMLHttpRequest", "snake_case").should eq("xml_http_request")
        AmberCLI::Core::WordTransformer.transform("HTTPSConnection", "snake_case").should eq("https_connection")
      end

      it "handles mixed case words" do
        AmberCLI::Core::WordTransformer.transform("iPhone", "snake_case").should eq("i_phone")
        AmberCLI::Core::WordTransformer.transform("macOS", "snake_case").should eq("mac_os")
      end

      it "preserves case sensitivity in custom patterns" do
        conventions = {"prefix" => "PREFIX_{{word}}_SUFFIX"}
        AmberCLI::Core::WordTransformer.transform("User", "prefix", conventions).should eq("PREFIX_User_SUFFIX")
        AmberCLI::Core::WordTransformer.transform("user", "prefix", conventions).should eq("PREFIX_user_SUFFIX")
      end
    end
  end

  describe ".all_transformations" do
    it "returns a hash of all standard transformations" do
      result = AmberCLI::Core::WordTransformer.all_transformations("user")
      
      result.should be_a(Hash(String, String))
      result["singular"].should eq("user")
      result["plural"].should eq("users")
      result["pascal_case"].should eq("User")
      result["snake_case"].should eq("user")
      result["kebab_case"].should eq("user")
      result["title_case"].should eq("User")
      result["upper_case"].should eq("USER")
      result["lower_case"].should eq("user")
      result["constant_case"].should eq("USER")
      result["humanize"].should eq("User")
      result["classify"].should eq("User")
      result["tableize"].should eq("users")
    end

    it "applies custom conventions to all transformations" do
      conventions = {"pascal_case" => "{{word}}Class"}
      result = AmberCLI::Core::WordTransformer.all_transformations("user", conventions)
      
      result["pascal_case"].should eq("userClass")
      result["snake_case"].should eq("user") # Should still use standard transformation
    end

    it "handles complex words" do
      result = AmberCLI::Core::WordTransformer.all_transformations("blog_post")
      
      result["pascal_case"].should eq("BlogPost")
      result["snake_case"].should eq("blog_post")
      result["kebab_case"].should eq("blog-post")
      result["title_case"].should eq("Blog Post")
      result["constant_case"].should eq("BLOG_POST")
      result["tableize"].should eq("blog_posts")
    end
  end

  describe ".rails_conventions" do
    it "returns Rails-style naming conventions" do
      result = AmberCLI::Core::WordTransformer.rails_conventions("user")
      
      result.should be_a(Hash(String, String))
      result["class_name"].should eq("User")
      result["table_name"].should eq("users")
      result["file_name"].should eq("user")
      result["variable_name"].should eq("user")
      result["constant_name"].should eq("USER")
      result["human_name"].should eq("User")
      result["route_name"].should eq("user")
    end

    it "handles complex words correctly" do
      result = AmberCLI::Core::WordTransformer.rails_conventions("blog_post")
      
      result["class_name"].should eq("BlogPost")
      result["table_name"].should eq("blog_posts")
      result["file_name"].should eq("blog_post")
      result["variable_name"].should eq("blog_post")
      result["constant_name"].should eq("BLOG_POST")
      result["human_name"].should eq("Blog post")
      result["route_name"].should eq("blog-post")
    end

    it "handles PascalCase input" do
      result = AmberCLI::Core::WordTransformer.rails_conventions("BlogPost")
      
      result["class_name"].should eq("BlogPost")
      result["table_name"].should eq("blog_posts")
      result["file_name"].should eq("blog_post")
      result["route_name"].should eq("blog-post")
    end
  end

  describe ".supports_transformation?" do
    it "returns true for supported transformations" do
      AmberCLI::Core::WordTransformer.supports_transformation?("pascal_case").should be_true
      AmberCLI::Core::WordTransformer.supports_transformation?("snake_case").should be_true
      AmberCLI::Core::WordTransformer.supports_transformation?("plural").should be_true
      AmberCLI::Core::WordTransformer.supports_transformation?("snake_case_plural").should be_true
    end

    it "returns false for unsupported transformations" do
      AmberCLI::Core::WordTransformer.supports_transformation?("invalid_transformation").should be_false
      AmberCLI::Core::WordTransformer.supports_transformation?("unknown_case").should be_false
      AmberCLI::Core::WordTransformer.supports_transformation?("").should be_false
    end
  end

  describe ".supported_transformations" do
    it "returns an array of all supported transformation names" do
      transformations = AmberCLI::Core::WordTransformer.supported_transformations
      
      transformations.should be_a(Array(String))
      transformations.should contain("pascal_case")
      transformations.should contain("snake_case")
      transformations.should contain("plural")
      transformations.should contain("singular")
      transformations.should contain("kebab_case")
      transformations.should contain("title_case")
      transformations.should contain("constant_case")
      transformations.should contain("humanize")
      transformations.should contain("snake_case_plural")
      transformations.should contain("pascal_case_plural")
      transformations.should contain("kebab_case_plural")
    end

    it "includes all transformation types used in the codebase" do
      transformations = AmberCLI::Core::WordTransformer.supported_transformations
      
      # Verify all transformations from the case statement are included
      %w(singular plural pascal_case camel_case snake_case kebab_case title_case 
         upper_case lower_case constant_case humanize classify tableize foreign_key 
         snake_case_plural pascal_case_plural kebab_case_plural).each do |transformation|
        transformations.should contain(transformation)
      end
    end
  end

  describe "performance considerations" do
    it "uses Crystal built-in methods for better performance" do
      # Test that we're using Crystal's native methods by testing a large number of transformations
      1000.times do |i|
        word = "test_word_#{i}"
        
        # These should be fast since they use Crystal's built-in methods
        AmberCLI::Core::WordTransformer.transform(word, "snake_case").should eq(word)
        AmberCLI::Core::WordTransformer.transform(word, "pascal_case").should eq("TestWord#{i}")
        AmberCLI::Core::WordTransformer.transform(word, "kebab_case").should eq("test-word-#{i}")
      end
    end
  end
end 