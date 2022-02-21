module Cache

using Downloads
using ZipFile

export HttpCache, cache_file

mutable struct HttpCache
    cache_dir::AbstractString
    headers::Union{Dict{AbstractString, AbstractString}, Nothing}

    HttpCache(cache_dir::AbstractString) = new(
        endswith(cache_dir, "/") ? cache_dir : cache_dir * "/",
        nothing
    )
end

function cache_file(cache::HttpCache, file_url::AbstractString)::AbstractString
    
    file_path::AbstractString = url_to_path(cache, file_url)
    
    isfile(file_path) && return file_path
    
    file_dir_path::AbstractString = join(split(file_path, "/")[1:end-1], "/")
    
    mkpath(file_dir_path)
    
    Downloads.download(file_url, file_path; headers=cache.headers)

    return file_path

end


function purge_file(cache::HttpCache, file_url::AbstractString)::Bool
    try
        rm(url_to_path(cache, file_url))
    catch
        return false
    end
    return true
end


function url_to_path(cache::HttpCache, url::AbstractString)::AbstractString
    rep::Pair{Regex, AbstractString} = r"https?://" => ""
    return cache.cache_dir * replace(url, rep)
end


function cache_edgar_enclosure(cache::HttpCache, enclosure_url::AbstractString)
    
    if endswith(enclosure_url, ".zip")
        
        enclosure_path::AbstractString = cache_file(cache, enclosure_url)
        
        parent_path::AbstractString = join(split(enclosure_url, "/")[1:end-1], "/")
        
        submission_dir_path::AbstractString = url_to_path(cache, parent_path)
        
        r::ZipFile.Reader = ZipFile.Reader(enclosure_path)
        
        for f in r.files
            write("$(submission_dir_path)/$(f.name)", read(f, String))
        end
        
        close(r)

    else
        throw("This is not a valid zip folder")
    end
end




end # Module