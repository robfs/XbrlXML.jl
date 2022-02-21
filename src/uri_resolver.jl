function resolve_uri(dir_uri::AbstractString, relative_uri::AbstractString)::AbstractString
    startswith(relative_uri, "http") && return relative_uri
    relative_uri = replace(relative_uri, r"^/" => "")
    relative_uri = replace(relative_uri, r"^./" => "")
    
    sep = Base.Filesystem.path_separator
    uri_parts = split(dir_uri, sep)
    
    if !startswith(dir_uri, "http")
        occursin(".", uri_parts[end]) && return normpath(dirname(dir_uri) * sep * relative_uri)
        return normpath(dir_uri * sep * relative_uri)
    end
    
    uri_parts = split(dir_uri, "/")
    if occursin(".", uri_parts[end]) 
        dir_uri = join(uri_parts[1:end-1], "/")
    end
    if endswith(dir_uri, "/")
        dir_uri *= "/"
    end
    
    absolute_uri = dir_uri * "/" * relative_uri
    if !startswith(dir_uri, "http") 
        absolute_uri = normpath(absolute_uri)
    end
    
    return replace(absolute_uri, r"/\w+/\.\./" => "/")
end
    
    