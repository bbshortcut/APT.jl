# APT module relying on sudo aptitude commands
module APT

export Package, readpkgs, writepkgs, rmpkgs!, addpkgs!
export update, install, remove, clean

immutable Package
    name::ASCIIString
end

pkglt(x, y) = x.name < y.name

sort!(pkgs::Vector{Package}) = Base.sort!(pkgs, lt=pkglt)

## Package file management

function readpkg(stream::IOStream)
    line = chomp(readline(stream))

    if line[1] == '+'
        (:install, Package(line[2:end]))
    elseif line[1] == '-'
        (:remove, Package(line[2:end]))
    else
        error("Bad package line.")
    end
end

function readpkgs(stream::IOStream,
                  installpkgs::Vector{Package},
                  removepkgs::Vector{Package})
    while !eof(stream)
        op, pkg = readpkg(stream)

        if op == :install
            push!(installpkgs, pkg)
        elseif op == :remove
            push!(removepkgs, pkg)
        else
            error("Bad package op.")
        end
    end

    (sort!(installpkgs), sort!(removepkgs))
end

function readpkgs(filepath::ASCIIString)
    installpkgs = Package[]
    removepkgs = Package[]

    try
        file = open(filepath)
        readpkgs(file, installpkgs, removepkgs)
        close(file)
        (installpkgs, removepkgs)
    catch
        error("Bad file path.")
    end
end

function writepkg(stream::IOStream, op::Symbol, pkg::Package)
    if op == :install
        write(stream, "+$(pkg.name)\n")
    elseif op == :remove
        write(stream, "-$(pkg.name)\n")
    else
        error("Bad package op.")
    end
end

function writepkgs(stream::IOStream,
                   installpkgs::Vector{Package},
                   removepkgs::Vector{Package})
    map(pkg -> writepkg(stream, :install, pkg), sort!(installpkgs))
    map(pkg -> writepkg(stream, :remove, pkg), sort!(removepkgs))
end

function writepkgs(filepath::ASCIIString,
                   installpkgs::Vector{Package},
                   removepkgs::Vector{Package})
        file = open(filepath, "w")
        writepkgs(file, installpkgs, removepkgs)
        close(file)
end

rmpkg!(pkg::Package, frompkgs::Vector{Package}) =
    filter!(p -> p.name != pkg.name, frompkgs)

rmpkgs!(pkgs::Vector{Package}, frompkgs::Vector{Package}) =
    map(pkg -> rmpkg!(pkg, frompkgs), pkgs)

rmpkgs!(pkgnames::Vector{ASCIIString}, frompkgs::Vector{Package}) =
    map(pkgname -> rmpkg!(Package(pkgname), frompkgs), pkgnames)

function in(pkg::Package, pkgs::Vector{Package})
    if length(pkgs) == 0
        false
    elseif length(pkgs) == 1
        pkg.name == pkgs[1].name
    else
        in(pkg, pkgs[1:1]) || in(pkg, pkgs[2:end])
    end
end

function addpkg!(pkg::Package,
                 topkgs::Vector{Package},
                 frompkgs::Vector{Package})
    if !in(pkg, topkgs)
        push!(topkgs, pkg)
        rmpkg!(pkg, frompkgs)
    end
end

addpkgs!(pkgs::Vector{Package},
         topkgs::Vector{Package},
         frompkgs::Vector{Package}) =
    map(pkg -> addpkg!(pkg, topkgs, frompkgs), pkgs)

addpkgs!(pkgnames::Vector{ASCIIString},
         topkgs::Vector{Package},
         frompkgs::Vector{Package}) =
    map(pkgname -> addpkg!(Package(pkgname), topkgs, frompkgs), pkgnames)

## aptitude commands

update() = run(`sudo aptitude update`)

install(pkgs::Vector{Package}) =
    run(`sudo aptitude install $([pkg.name for pkg in pkgs])`)
install(pkgnames::Vector{ASCIIString}) = install(map(Package, pkgnames))

remove(pkgs::Vector{Package}) =
    run(`sudo aptitude --purge remove $([pkg.name for pkg in pkgs])`)
remove(pkgnames::Vector{ASCIIString}) = remove(map(Package, pkgnames))

upgrade() = run(`sudo aptitude upgrade`)

clean() = run(`sudo aptitude clean`)

end # module
