require "../spec_helper"

describe AmberCLI::Vendor::Inflector do
  describe ".pluralize" do
    context "basic pluralization" do
      it "adds 's' to regular words" do
        AmberCLI::Vendor::Inflector.pluralize("cat").should eq("cats")
        AmberCLI::Vendor::Inflector.pluralize("dog").should eq("dogs")
        AmberCLI::Vendor::Inflector.pluralize("book").should eq("books")
      end

      it "handles words ending in 'y'" do
        AmberCLI::Vendor::Inflector.pluralize("company").should eq("companies")
        AmberCLI::Vendor::Inflector.pluralize("city").should eq("cities")
        AmberCLI::Vendor::Inflector.pluralize("baby").should eq("babies")
      end

      it "handles words ending in consonant + 'y'" do
        AmberCLI::Vendor::Inflector.pluralize("party").should eq("parties")
        AmberCLI::Vendor::Inflector.pluralize("family").should eq("families")
      end

      it "handles words ending in vowel + 'y'" do
        AmberCLI::Vendor::Inflector.pluralize("boy").should eq("boys")
        AmberCLI::Vendor::Inflector.pluralize("day").should eq("days")
      end

      it "handles words ending in 'ss'" do
        AmberCLI::Vendor::Inflector.pluralize("class").should eq("classes")
        AmberCLI::Vendor::Inflector.pluralize("glass").should eq("glasses")
      end

      it "handles words ending in 'sh'" do
        AmberCLI::Vendor::Inflector.pluralize("wish").should eq("wishes")
        AmberCLI::Vendor::Inflector.pluralize("flash").should eq("flashes")
      end

      it "handles words ending in 'ch'" do
        AmberCLI::Vendor::Inflector.pluralize("church").should eq("churches")
        AmberCLI::Vendor::Inflector.pluralize("lunch").should eq("lunches")
      end

      it "handles words ending in 'x'" do
        AmberCLI::Vendor::Inflector.pluralize("box").should eq("boxes")
        AmberCLI::Vendor::Inflector.pluralize("tax").should eq("taxes")
      end

      it "handles words ending in 'fe'" do
        AmberCLI::Vendor::Inflector.pluralize("wife").should eq("wives")
        AmberCLI::Vendor::Inflector.pluralize("knife").should eq("knives")
        AmberCLI::Vendor::Inflector.pluralize("life").should eq("lives")
      end

      it "handles words ending in 'f'" do
        AmberCLI::Vendor::Inflector.pluralize("half").should eq("halves")
        AmberCLI::Vendor::Inflector.pluralize("leaf").should eq("leaves")
        AmberCLI::Vendor::Inflector.pluralize("shelf").should eq("shelves")
      end
    end

    context "irregular plurals (fixed in vendored version)" do
      it "handles foot/feet correctly" do
        AmberCLI::Vendor::Inflector.pluralize("foot").should eq("feet")
      end

      it "handles tooth/teeth correctly" do
        AmberCLI::Vendor::Inflector.pluralize("tooth").should eq("teeth")
      end

      it "handles goose/geese correctly" do
        AmberCLI::Vendor::Inflector.pluralize("goose").should eq("geese")
      end

      it "handles mouse/mice correctly" do
        AmberCLI::Vendor::Inflector.pluralize("mouse").should eq("mice")
      end

      it "preserves case in irregular words" do
        AmberCLI::Vendor::Inflector.pluralize("Foot").should eq("Feet")
        AmberCLI::Vendor::Inflector.pluralize("MOUSE").should eq("MICE")
      end
    end

    context "original irregular plurals" do
      it "handles common irregular plurals" do
        AmberCLI::Vendor::Inflector.pluralize("person").should eq("people")
        AmberCLI::Vendor::Inflector.pluralize("child").should eq("children")
        AmberCLI::Vendor::Inflector.pluralize("man").should eq("men")
        AmberCLI::Vendor::Inflector.pluralize("woman").should eq("women")
      end
    end

    context "programming-specific terms" do
      it "handles database/programming terms" do
        AmberCLI::Vendor::Inflector.pluralize("index").should eq("indices")
        AmberCLI::Vendor::Inflector.pluralize("vertex").should eq("vertices")
        AmberCLI::Vendor::Inflector.pluralize("matrix").should eq("matrices")
        AmberCLI::Vendor::Inflector.pluralize("datum").should eq("data")
      end
    end

    context "uncountable words" do
      it "doesn't change uncountable words" do
        AmberCLI::Vendor::Inflector.pluralize("sheep").should eq("sheep")
        AmberCLI::Vendor::Inflector.pluralize("fish").should eq("fish")
        AmberCLI::Vendor::Inflector.pluralize("information").should eq("information")
        AmberCLI::Vendor::Inflector.pluralize("money").should eq("money")
      end
    end
  end

  describe ".singularize" do
    context "basic singularization" do
      it "removes 's' from regular words" do
        AmberCLI::Vendor::Inflector.singularize("cats").should eq("cat")
        AmberCLI::Vendor::Inflector.singularize("dogs").should eq("dog")
        AmberCLI::Vendor::Inflector.singularize("books").should eq("book")
      end

      it "handles words ending in 'ies'" do
        AmberCLI::Vendor::Inflector.singularize("companies").should eq("company")
        AmberCLI::Vendor::Inflector.singularize("cities").should eq("city")
        AmberCLI::Vendor::Inflector.singularize("babies").should eq("baby")
      end

      it "handles words ending in 'ses'" do
        AmberCLI::Vendor::Inflector.singularize("classes").should eq("class")
        AmberCLI::Vendor::Inflector.singularize("glasses").should eq("glass")
      end

      it "handles words ending in 'ves'" do
        AmberCLI::Vendor::Inflector.singularize("wives").should eq("wife")
        AmberCLI::Vendor::Inflector.singularize("knives").should eq("knife")
        AmberCLI::Vendor::Inflector.singularize("halves").should eq("half")
      end
    end

    context "irregular singulars (fixed in vendored version)" do
      it "handles feet/foot correctly" do
        AmberCLI::Vendor::Inflector.singularize("feet").should eq("foot")
      end

      it "handles teeth/tooth correctly" do
        AmberCLI::Vendor::Inflector.singularize("teeth").should eq("tooth")
      end

      it "handles geese/goose correctly" do
        AmberCLI::Vendor::Inflector.singularize("geese").should eq("goose")
      end

      it "handles mice/mouse correctly" do
        AmberCLI::Vendor::Inflector.singularize("mice").should eq("mouse")
      end
    end

    context "original irregular singulars" do
      it "handles common irregular singulars" do
        AmberCLI::Vendor::Inflector.singularize("people").should eq("person")
        AmberCLI::Vendor::Inflector.singularize("children").should eq("child")
        AmberCLI::Vendor::Inflector.singularize("men").should eq("man")
        AmberCLI::Vendor::Inflector.singularize("women").should eq("woman")
      end
    end

    context "programming-specific terms" do
      it "handles database/programming terms" do
        AmberCLI::Vendor::Inflector.singularize("indices").should eq("index")
        AmberCLI::Vendor::Inflector.singularize("vertices").should eq("vertex")
        AmberCLI::Vendor::Inflector.singularize("matrices").should eq("matrix")
        AmberCLI::Vendor::Inflector.singularize("data").should eq("datum")
      end
    end
  end

  describe ".classify" do
    it "converts table names to class names" do
      AmberCLI::Vendor::Inflector.classify("users").should eq("User")
      AmberCLI::Vendor::Inflector.classify("blog_posts").should eq("BlogPost")
      AmberCLI::Vendor::Inflector.classify("companies").should eq("Company")
    end

    it "handles irregular plurals correctly" do
      AmberCLI::Vendor::Inflector.classify("people").should eq("Person")
      AmberCLI::Vendor::Inflector.classify("children").should eq("Child")
      AmberCLI::Vendor::Inflector.classify("feet").should eq("Foot")
    end

    it "works with symbols" do
      AmberCLI::Vendor::Inflector.classify(:users).should eq("User")
      AmberCLI::Vendor::Inflector.classify(:blog_posts).should eq("BlogPost")
    end
  end

  describe ".foreign_key" do
    it "creates foreign keys from class names" do
      AmberCLI::Vendor::Inflector.foreign_key("User").should eq("user_id")
      AmberCLI::Vendor::Inflector.foreign_key("BlogPost").should eq("blog_post_id")
      AmberCLI::Vendor::Inflector.foreign_key("Company").should eq("company_id")
    end

    it "handles namespaced class names" do
      AmberCLI::Vendor::Inflector.foreign_key("Admin::User").should eq("user_id")
      AmberCLI::Vendor::Inflector.foreign_key("Blog::Post").should eq("post_id")
    end

    it "supports separator option" do
      AmberCLI::Vendor::Inflector.foreign_key("User", false).should eq("userid")
      AmberCLI::Vendor::Inflector.foreign_key("BlogPost", false).should eq("blogpostid")
    end
  end

  describe "performance improvements" do
    it "uses Crystal's built-in methods" do
      # Test that classify uses Crystal's camelcase
      result = AmberCLI::Vendor::Inflector.classify("blog_posts")
      result.should eq("BlogPost")

      # Test that foreign_key uses Crystal's underscore
      result = AmberCLI::Vendor::Inflector.foreign_key("BlogPost")
      result.should eq("blog_post_id")
    end
  end

  describe "backward compatibility" do
    it "maintains exact same API as original inflector" do
      # Test that all method signatures are identical
      AmberCLI::Vendor::Inflector.responds_to?(:pluralize).should be_true
      AmberCLI::Vendor::Inflector.responds_to?(:singularize).should be_true
      AmberCLI::Vendor::Inflector.responds_to?(:classify).should be_true
      AmberCLI::Vendor::Inflector.responds_to?(:foreign_key).should be_true
    end

    it "handles edge cases like original" do
      # Empty strings
      AmberCLI::Vendor::Inflector.pluralize("").should eq("")
      AmberCLI::Vendor::Inflector.singularize("").should eq("")
      
      # Single character
      AmberCLI::Vendor::Inflector.pluralize("a").should eq("as")
      AmberCLI::Vendor::Inflector.singularize("s").should eq("")
    end
  end
end 