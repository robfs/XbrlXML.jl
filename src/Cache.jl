"""
Interface to local store of files used for parsing XBRL.
"""
module Cache

using Downloads
using ZipFile

export HttpCache
export cacheheader!, cacheheaders!, cacheheaders, cachedir
export cachefile, purgefile, urltopath, cache_edgar_enclosure

"""
    HttpCache(cache_dir="./cache/", headers=Dict())

Create a cache to store files locally for reuse.

`headers` are passed to http `Downloads.download`. Services such as SEC require you to
disclose information about your application.

# Example
```jldoctest
julia> using XbrlXML

julia> cache = HttpCache("/Users/user/cache/")
/Users/user/cache/
```
"""
mutable struct HttpCache
    cachedir::String
    headers::Dict{String, String}
    HttpCache(cachedir="./cache/", headers=Dict()) = new(
        endswith(cachedir, "/") ? cachedir : cachedir * "/",
        headers
    )
end

"""
    cachedir(cache::HttpCache)::String

Return the local directory of a cache.

# Example
```jldoctest
julia> using XbrlXML

julia> cache = HttpCache("/Users/user/cache/");

julia> cachedir(cache)
"/Users/user/cache/"
```
"""
cachedir(cache::HttpCache)::String = cache.cachedir

"""
    cacheheaders(cache::HttpCache)::Dict

Return the headers of a cache.

# Example
```jldoctest
julia> using XbrlXML

julia> cache = HttpCache("/Users/user/cache/");

julia> cacheheader!(cache, "User-Agent" => "You youremail@domain.com");

julia> cacheheaders(cache)
Dict{String, String} with 1 entry:
  "User-Agent" => "You youremail@domain.com"
```
"""
cacheheaders(cache::HttpCache)::Dict{String,String} = cache.headers

Base.show(io::IO, c::HttpCache) = print(
    io, "$(abspath(cachedir(c)))"
)

"""
    cacheheader!(cache::HttpCache, header::Pair)::Dict

Add a header pair to a cache and return the headers.

# Example
```jldoctest
julia> using XbrlXML

julia> cache = HttpCache("/Users/user/cache/");

julia> cacheheader!(cache, "User-Agent" => "You youremail@domain.com")
Dict{String, String} with 1 entry:
  "User-Agent" => "You youremail@domain.com"
```
"""
function cacheheader!(cache::HttpCache, header::Pair{String,String})::Dict{String,String}
    get!(cache.headers, header.first, header.second)
    return cacheheaders(cache)
end

"""
    cacheheaders!(cache::HttpCache, header::Vector{Pair})::Dict

Add multiple header pairs to a cache and return the headers.

# Example
```jldoctest
julia> using XbrlXML

julia> cache = HttpCache("/Users/user/cache/");

julia> headers = ["User-Agent" => "You youremail@domain.com", "From" => "You"];

julia> cacheheaders!(cache, headers)
Dict{String, String} with 2 entries:
  "From"       => "You"
  "User-Agent" => "You youremail@domain.com"
```
"""
function cacheheaders!(cache::HttpCache, headers::Vector{Pair{String,String}})
    for header in headers
        cacheheader!(cache, header)
    end
    cacheheaders(cache)
end

"""
    cachefile(cache::HttpCache, file_url)::String

Save a file located at `file_url` to a local cache.
"""
function cachefile(cache::HttpCache, file_url::String)::String
    file_path::String = urltopath(cache, file_url)
    isfile(file_path) && return file_path
    file_dir_path::AbstractString = join(split(file_path, "/")[1:end-1], "/")
    mkpath(file_dir_path)
    Downloads.download(file_url, file_path; headers=cacheheaders(cache))
    return file_path
end

"""
    purgefile(cache::HttpCache, file_url)::Bool

Remove a file, based on its URL, from a local cache.
"""
function purgefile(cache::HttpCache, file_url::String)::Bool
    try
        rm(urltopath(cache, file_url))
    catch
        return false
    end
    return true
end

"""
    urltopath(cache::HttpCache, url)::String

Convert a file's `url` to a local cache file.
"""
function urltopath(cache::HttpCache, url::String)::String
    rep::Pair{Regex, String} = r"https?://" => ""
    return cachedir(cache) * replace(url, rep)
end

"""
    cache_edgar_enclosure(cache::HttpCache, enclosure_url)

Cache the zip folder from SEC containing all XBRL related files for a given submissions.

Due to the fact that the zip compression is very effective on xbrl submissions that
naturally contain repeating text, it is way more efficient to download the zip folder and
extract it.
This will most often be the most efficient method for downloading the submission.
One way to get the zip enclosure url is through the Structured Disclosure RSS Feeds
provided by the SEC: https://www.sec.gov/structureddata/rss-feeds-submitted-filings
"""
function cache_edgar_enclosure(cache::HttpCache, enclosure_url::String)::String
    if endswith(enclosure_url, ".zip")
        enclosure_path::AbstractString = cachefile(cache, enclosure_url)
        parent_path::AbstractString = join(split(enclosure_url, "/")[1:end-1], "/")
        submission_dir_path::String = urltopath(cache, parent_path)
        r::ZipFile.Reader = ZipFile.Reader(enclosure_path)
        for f in r.files
            write("$(submission_dir_path)/$(f.name)", read(f, String))
        end
        close(r)
    else
        throw(error("This is not a valid zip folder"))
    end
    return submission_dir_path
end

"""
    find_entry_file(cache::HttpCache, dirpath::String)::Union{String,Nothing}

Find the most likely entry file in provided filing directory.

This function only works for enclosed SEC submissions that where already downloaded.
Will return only the most likely file path for the instance document.
"""
function find_entry_file(cache::HttpCache, dirpath::String)::Union{String,Nothing}
    valid_files::Vector{AbstractString} = []
    for ext in [".htm", ".xml", ".xsd"]
        for f in readdir(dir_path, join=true)
            isfile(f) && endswith(lowercase(f), ext) && push!(valid_files, f)
        end
    end
    entry_candidates::Vector{AbstractString} = []
    for file1 in valid_files
        (filedir, filename) = rsplit(file1, Base.Filesystem.path_separator; limit=2)
        foundinother::Bool = false
        for file2 in valid_files
            if file1 != file2
                file2contents::AbstractString = open(file2) do f
                    read(f)
                end
                if occursin(filename, file2contents)
                    foundinother = true
                    break
                end
            end
        end
        !foundinother && push!(entry_candidates, (file1, fileszie(file1)))
    end
    sort!(entry_candidates; by=x -> x[2], rev=true)
    if length(entry_candidates) > 0
        (filepath::String, size) = entry_candidates[1]
        return filepath
    end
    return nothing
end


end # Module
