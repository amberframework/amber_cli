require "../amber_cli_spec"

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
        AmberCLI::Core::WordTransformer.transform("hero", "plural").should eq("heros")
      end

      it "converts to camel_case" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "camel_case").should eq("UserProfile")
        AmberCLI::Core::WordTransformer.transform("blog_post", "camel_case").should eq("BlogPost")
        AmberCLI::Core::WordTransformer.transform("single", "camel_case").should eq("Single")
      end

      it "converts to pascal_case (same as camel_case)" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "pascal_case").should eq("UserProfile")
        AmberCLI::Core::WordTransformer.transform("blog_post", "pascal_case").should eq("BlogPost")
      end

      it "converts to snake_case" do
        AmberCLI::Core::WordTransformer.transform("UserProfile", "snake_case").should eq("user_profile")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "snake_case").should eq("blog_post")
        AmberCLI::Core::WordTransformer.transform("user", "snake_case").should eq("user")
      end

      it "converts to kebab_case" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "kebab_case").should eq("user-profile")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "kebab_case").should eq("blog-post")
      end

      it "converts to title_case" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "title_case").should eq("User Profile")
        AmberCLI::Core::WordTransformer.transform("blog_post", "title_case").should eq("Blog Post")
      end

      it "converts to upper_case" do
        AmberCLI::Core::WordTransformer.transform("user", "upper_case").should eq("USER")
        AmberCLI::Core::WordTransformer.transform("blog_post", "upper_case").should eq("BLOG_POST")
      end

      it "converts to lower_case" do
        AmberCLI::Core::WordTransformer.transform("USER", "lower_case").should eq("user")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "lower_case").should eq("blogpost")
      end

      it "converts to constant_case" do
        AmberCLI::Core::WordTransformer.transform("user_profile", "constant_case").should eq("USER_PROFILE")
        AmberCLI::Core::WordTransformer.transform("BlogPost", "constant_case").should eq("BLOG_POST")
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

      it "falls back to standard transformations when custom pattern not found" do
        conventions = {"custom_pattern" => "{{word}}Custom"}
        
        AmberCLI::Core::WordTransformer.transform("user", "snake_case", conventions).should eq("user")
        AmberCLI::Core::WordTransformer.transform("user", "pascal_case", conventions).should eq("User")
      end

      it "returns original word when transformation not recognized" do
        AmberCLI::Core::WordTransformer.transform("user", "unknown_transformation").should eq("user")
      end
    end

    context "edge cases" do
      it "handles empty strings" do
        AmberCLI::Core::WordTransformer.transform("", "plural").should eq("")
        AmberCLI::Core::WordTransformer.transform("", "singular").should eq("")
        AmberCLI::Core::WordTransformer.transform("", "snake_case").should eq("")
      end

      it "handles single character words" do
        AmberCLI::Core::WordTransformer.transform("a", "plural").should eq("as")
        AmberCLI::Core::WordTransformer.transform("i", "plural").should eq("is")
      end

      it "handles irregular plurals correctly" do
        # These test proper English pluralization using inflector.cr
        AmberCLI::Core::WordTransformer.transform("mouse", "plural").should eq("mice") # proper inflection
        AmberCLI::Core::WordTransformer.transform("child", "plural").should eq("children") # proper inflection
      end

      it "handles words ending in 'ss'" do
        AmberCLI::Core::WordTransformer.transform("class", "plural").should eq("classes")
        AmberCLI::Core::WordTransformer.transform("glass", "plural").should eq("glasses")
      end

      it "handles acronyms and abbreviations" do
        AmberCLI::Core::WordTransformer.transform("API", "snake_case").should eq("api")
        AmberCLI::Core::WordTransformer.transform("XMLHttpRequest", "snake_case").should eq("xml_http_request")
      end
    end
  end
end 