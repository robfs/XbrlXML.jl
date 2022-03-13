using XbrlXML
using Test
using Documenter

@testset verbose = true "XbrlXML.jl" begin
    @testset "Cache" begin
        cachedir::String = abspath("./cache/") * "/"
        cache::HttpCache = HttpCache(cachedir)
        testurl::String = "https://www.w3schools.com/xml/note.xml"
        expectedpath::String = cachedir * "www.w3schools.com/xml/note.xml"
        rm(expectedpath; force=true)
        @test cachefile(cache, testurl) == expectedpath
        @test isfile(expectedpath)
        @test purgefile(cache, testurl)
        @test !(isfile(expectedpath))
        rm(cachedir; force=true, recursive=true)
    end
    @testset verbose = true "Linkbases" begin
        @testset "Local Linkbases" begin
            linkbasepath::String = abspath("./data/example-lab.xml")
            linkbase::XbrlXML.Linkbase = parselinkbase(linkbasepath, XbrlXML.Linkbases.LABEL)
            rootlocator::XbrlXML.Locator = linkbase.extended_links[1].root_locators[1]
            @test length(linkbase.extended_links) == 1
            @test rootlocator.name == "loc_Assets"
            labelarcs::Vector{XbrlXML.LabelArc} = rootlocator.children
            @test labelarcs[1].labels[1].text == "Assets, total"
            @test occursin("An asset is a resource with economic value",
                            labelarcs[2].labels[1].text)
            linkbasepath = abspath("./data/example-cal.xml")
            linkbase = parselinkbase(linkbasepath, XbrlXML.Linkbases.CALCULATION)
            assetslocator::XbrlXML.Locator = linkbase.extended_links[1].root_locators[1]
            @test assetslocator.concept_id == "example_Assets"
            @test assetslocator.children[1].to_locator.concept_id == "example_NonCurrentAssets"
            @test assetslocator.children[2].to_locator.concept_id == "example_CurrentAssets"
        end
        if isfile(abspath("./.env"))
            @testset "Remote Linkbases" begin
                cachedir::String = abspath("./cache/")
                cache::HttpCache = HttpCache(cachedir)
                header!(cache, "User-Agent" => "Test test@test.com")
                linkbaseurl::String = "https://www.esma.europa.eu/taxonomy/2019-03-27/esef_cor-lab-de.xml"
                linkbase = parselinkbase_url(linkbaseurl, XbrlXML.Linkbases.LABEL, cache)
                @test length(linkbase.extended_links) == 1
                @test length(linkbase.extended_links[1].root_locators) == 5028
                assetslocator = filter(x -> x.name == "Assets", linkbase.extended_links[1].root_locators)[1]
                assetslabel::XbrlXML.Label = assetslocator.children[1].labels[1]
                @test assetslabel.text == "Vermögenswerte"
                rm(cachedir; force=true, recursive=true)
            end
        end
    end
    @testset verbose = true "Taxonomies" begin
        @testset "Local Taxonomies" begin
            cachedir::String = abspath("./cache/")
            cache::HttpCache = HttpCache(cachedir)
            extensionschemapath::String = abspath("./data/example.xsd")
            tax::XbrlXML.TaxonomySchema = parsetaxonomy(extensionschemapath, cache)
            srttax::XbrlXML.TaxonomySchema = gettaxonomy(tax, "http://fasb.org/srt/2020-01-31")
            @test length(srttax.concepts) == 489
            @test length(tax.concepts["example_Assets"].labels) == 2
        end
        if isfile(abspath("./.env"))
            @testset "Remote Taxonomies" begin
                cachedir::String = abspath("./cache/")
                cache::HttpCache = HttpCache(cachedir)
                header!(cache, "User-Agent" => "Test test@test.com")
                schemaurl::String = "https://www.sec.gov/Archives/edgar/data/320193/000032019321000010/aapl-20201226.xsd"
                tax = parsetaxonomy_url(schemaurl, cache)
                @test length(tax.concepts) == 65
                usgaaptax::XbrlXML.TaxonomySchema = gettaxonomy(tax, "http://fasb.org/us-gaap/2020-01-31")
                @test length(usgaaptax.concepts) == 17281
                @test length(tax.concepts["aapl_MacMember"].labels) == 3
                rm(cachedir; force=true, recursive=true)
            end
        end
    end
    @testset "Transformations" begin
        testtransforms::Vector{Vector{String}} = [
            # [format,value,expected]
            ["booleanfalse", "no", "false"],
            ["booleantrue", "yeah", "true"],
            ["datedaymonth", "2.12", "--12-02"],
            ["datedaymonthen", "2. December", "--12-02"],
            ["datedaymonthyear", "2.12.2021", "2021-12-02"],
            ["datedaymonthyearen", "02. December 2021", "2021-12-02"],
            ["datemonthday", "1.2", "--01-02"],
            ["datemonthdayen", "Jan 02", "--01-02"],
            ["datemonthdayyear", "12-30-2021", "2021-12-30"],
            ["datemonthdayyearen", "March 31, 2021", "2021-03-31"],
            ["dateyearmonthday", "2021.12.31", "2021-12-31"],
            ["datemonthyear", "12 2021", "2021-12"],
            ["datemonthyearen", "December 2021", "2021-12"],
            ["dateyearmonthen", "2021 December", "2021-12"],
            ["nocontent", "Bla bla", ""],
            ["numcommadecimal", "1.499,99", "1499.99"],
            ["numdotdecimal", "1,499.99", "1499.99"],
            ["zerodash", "-", "0"],
        ]
        for testtransform in testtransforms
            expected::String = testtransform[3]
            received::String = XbrlXML.Instance.transform_ixt(testtransform[2], testtransform[1])
            @test expected == received
        end
        testtransforms = [
            # [format,value,expected]
            ["numwordsen", "no", "0"],
            ["numwordsen", "None", "0"],
            ["numwordsen", "nineteen hundred forty-four", "1944"],
            ["numwordsen", "Seventy Thousand and one", "70001"]
        ]
        for testtransform in testtransforms
            expected = testtransform[3]
            received = XbrlXML.Instance.transform_ixt_sec(testtransform[2], testtransform[1])
            @test expected == received
        end
    end

    @testset verbose = true "URI Helpers" begin
        @testset "Resolver" begin
            test_arr = [
                # test paths
                (("E:\\Programming\\python\\xbrl_parser\\tests\\data\\example.xsd", "/example-lab.xml"),
                    join(["E:", "Programming", "python", "xbrl_parser", "tests", "data", "example-lab.xml"], Base.Filesystem.path_separator)),
                ((raw"E:\Programming\python\xbrl_parser\tests\data\example.xsd", "/example-lab.xml"),
                    join(["E:", "Programming", "python", "xbrl_parser", "tests", "data", "example-lab.xml"], Base.Filesystem.path_separator)),
                (("E:/Programming/python/xbrl_parser/tests/data/example.xsd", "/example-lab.xml"),
                    join(["E:", "Programming", "python", "xbrl_parser", "tests", "data", "example-lab.xml"], Base.Filesystem.path_separator)),
                # test different path separators
                (("E:\\Programming\\python\\xbrl_parser\\tests\\data/example.xsd", "/example-lab.xml"),
                    join(["E:", "Programming", "python", "xbrl_parser", "tests", "data", "example-lab.xml"], Base.Filesystem.path_separator)),
                # test directory traversal
                (("E:/Programming/python/xbrl_parser/tests/data/", "/../example-lab.xml"),
                    join(["E:", "Programming", "python", "xbrl_parser", "tests", "example-lab.xml"], Base.Filesystem.path_separator)),
                (("E:/Programming/python/xbrl_parser/tests/data", "./../example-lab.xml"),
                    join(["E:", "Programming", "python", "xbrl_parser", "tests", "example-lab.xml"], Base.Filesystem.path_separator)),
                (("E:/Programming/python/xbrl_parser/tests/data/example.xsd", "../../example-lab.xml"),
                    join(["E:", "Programming", "python", "xbrl_parser", "example-lab.xml"], Base.Filesystem.path_separator)),
                # test urls
                (("http://example.com/a/b/c/d/e/f/g", "file.xml"), "http://example.com/a/b/c/d/e/f/g/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "/file.xml"), "http://example.com/a/b/c/d/e/f/g/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "./file.xml"), "http://example.com/a/b/c/d/e/f/g/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "../file.xml"), "http://example.com/a/b/c/d/e/f/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "/../file.xml"), "http://example.com/a/b/c/d/e/f/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "./../file.xml"), "http://example.com/a/b/c/d/e/f/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "../../file.xml"), "http://example.com/a/b/c/d/e/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "/../../file.xml"), "http://example.com/a/b/c/d/e/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g", "./../../file.xml"), "http://example.com/a/b/c/d/e/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g/", "../../../file.xml"), "http://example.com/a/b/c/d/file.xml"),
                (("http://example.com/a/b/c/d/e/f/g.xml", "../../../file.xml"), "http://example.com/a/b/c/file.xml")
            ]
            for elem in test_arr
                # only windows uses the \\ file path separator
                # for now skip the first tests with \\ if we are on a unix system, since the \\ is an invalid path on
                # a unix like os such as macOS or linux
                if startswith(elem[1][1], "E:\\") && Base.Filesystem.path_separator != "\\"
                    # @info "Skipping Windows specific unit test case"
                    continue
                end
                expected = elem[2]
                received = XbrlXML.Taxonomy.resolve_uri(elem[1][1], elem[1][2])
                @test expected == received
            end
        end
        @testset "Comparisons" begin
            test_arr = [
                ["./abc", "abc", true],
                ["./abc", "\\abc\\", true],
                ["./abc", "abcd", false],
                ["http://abc.de", "https://abc.de", true]
            ]
            for test_case in test_arr
                expected = test_case[3]
                received = XbrlXML.Taxonomy.compare_uri(test_case[1], test_case[2])
                @test expected == received
            end
        end
    end
    @testset verbose = true "Instance Tests" begin
        @testset "Local Instances" begin
            cachedir::String = abspath("./cache/")
            cache::HttpCache = HttpCache(cachedir)
            instancedocurl::String = "./data/example.xml"
            inst::XbrlInstance = parsexbrl(instancedocurl, cache)
            @test length(facts(inst)) == 1
            instancedocurl = "./data/example.html"
            inst = parseixbrl(instancedocurl, cache)
            @test length(facts(inst)) == 3
        end
        if isfile(abspath("./.env"))
            @testset "Remote Instances" begin
                cachedir::String = abspath("./cache/")
                cache::HttpCache = HttpCache(cachedir)
                header!(cache, "User-Agent" => "Test test@test.com")
                url::String = "https://www.sec.gov/Archives/edgar/data/320193/000032019321000010/aapl-20201226.htm"
                inst = parseixbrl_url(url, cache)
                @test length(inst.context_map) == 207
                @test length(inst.unit_map) == 9
                rm(cachedir; force=true, recursive=true)
            end
        end
    end
    doctest(XbrlXML)
end
