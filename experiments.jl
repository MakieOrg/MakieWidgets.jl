# TODOs
# Fix picking  index error (resize?!)
# Fix picking in browser
# Resize API
# Displayable object for JSServe + Figure
# First resize_to!
# Card Title, shadow, bgcolor kwords
# Document Slider

using JSServe, WGLMakie
import JSServe.TailwindDashboard as D
# https://tailwindcss.com/docs/flex

rm(JSServe.bundle_path(WGLMakie.WGL))
struct PlayButton{T}
    button::JSServe.Button
    range::AbstractVector{T}
    value::Observable{T}
    task::Base.RefValue{Union{Nothing,Task}}
    steps_per_second::Base.RefValue{Float64}
end

function PlayButton(range::AbstractVector{T}; steps_per_second=10) where {T}
    button = JSServe.Button("⏵"; class="text-xl")
    value = Observable{T}(first(range))
    sps = Base.RefValue{Float64}(steps_per_second)
    return PlayButton{T}(button, range, value, Base.RefValue{Union{Task,Nothing}}(nothing), sps)
end

function JSServe.jsrender(session::Session, playbutton::PlayButton)
    if !isnothing(playbutton.task[])
        error("Same PlayButton used in multiple apps. Please create a PlayButton for each App and don't share it.")
    end
    playing = Threads.Atomic{Bool}(false)
    button = playbutton.button
    on(button.value) do _
        playing[] = !playing[]
        return button.content[] = playing[] ? "⏵" : "⏸"
    end
    range = playbutton.range
    playbutton.task[] = @async begin
        index = 1
        while session.status != JSServe.CLOSED
            try
                tstart = time()
                if playing[]
                    index = mod1(index + 1, length(range))
                    playbutton.value[] = range[index]
                end
                telapsed = time() - tstart
                seconds_to_sleep = (1 / playbutton.steps_per_second[])
                x = max(0.0001, seconds_to_sleep - telapsed)
                sleep(x)
            catch e
                @warn "error in player" exception = (e, Base.catch_backtrace)
            end
        end
        println("DONE!")
    end
    return JSServe.jsrender(session, button)
end

App() do
    WGLMakie.activate!(resize_to=nothing)
    f, ax, p = scatter(1:4; markersize=40, axis=(backgroundcolor=:transparent,),
                       figure=(; backgroundcolor=:transparent, resolution=(500, 500)))
    button = PlayButton(1:10)
    on(button.value) do i
        p[1] = 1:i
        return autolimits!(ax)
    end
    cards = DOM.div(D.Card("A"),
                    D.Card(DOM.div(button; class="flex justify-center"); class="bg-indigo-500"),
                    D.Card("C"),
                    ; class="flex justify-center")
    plot = DOM.div(f; class="flex justify-center")
    return DOM.div(JSServe.TailwindCSS,  D.Card(DOM.div(cards, plot)))
end

using WGLMakie, Makie, JSServe

function xy_data(x, y)
    r = sqrt(x^2 + y^2)
    return r == 0.0 ? 1.0f0 : (sin(r) / r)
end
App() do
    WGLMakie.activate!(; resize_to=nothing)
    N = 60

    l = range(-10; stop=10, length=N)
    z = Float32[xy_data(x, y) for x in l, y in l]

    f1, ax, p = scatter(1:4; markersize=40, axis=(backgroundcolor=:transparent,),
                        figure=(; backgroundcolor=:transparent, size=(500, 500)))
    f2, ax, p = scatter(rand(Point3f, 10); axis=(scenekw=(; backgroundcolor=:transparent),),
                        figure=(; backgroundcolor=:transparent, size=(500, 500)))
    f3, ax, p = meshscatter(rand(Point3f, 10); axis=(scenekw=(; backgroundcolor=:transparent),),
                            figure=(; backgroundcolor=:transparent, size=(500, 500)))
    f4, ax, p = surface(-1 .. 1, -1 .. 1, z; colormap=:Spectral,
                        axis=(scenekw=(; backgroundcolor=:transparent),),
                        figure=(; backgroundcolor=:transparent, size=(500, 500)))
    cards = D.FlexGrid(D.Card(WGLMakie.WithConfig(f1; resize_to=:parent)),
                       D.Card(f2),
                       D.Card(f3),
                       D.Card(f4);
                       class="flex justify-center")
    return DOM.div(JSServe.TailwindCSS, cards)
end


using JSServe, WGLMakie, Colors
import JSServe.TailwindDashboard as D
JSServe.browser_display()

to_css_color(color::Union{Symbol,String}) = color
function to_css_color(color::Colorant)
    rgba = convert(RGBA{Float64}, color)
    return "rgba($(rgba.r * 255), $(rgba.g * 255), $(rgba.b * 255), $(rgba.alpha))"
end

function Card(content;
              class="",
              style="",
              backgroundcolor=RGBA(1, 1, 1, 0.2),
              shadow_size="0 4px 8px",
              padding="6px",
              margin="2px",
              shadow_color=RGBA(0, 0, 0.2, 0.2),
              width="fit-content",
              height="fit-content",
              attributes...)
    css = """
        display: block;
        width: $(width);
        height: $(height);
        padding: $(padding);
        margin: $(margin);
        background-color: $(to_css_color(backgroundcolor));
        border-radius: 10px;
        box-shadow: $(shadow_size) $(to_css_color(shadow_color));
    """

    return DOM.div(content;
                   style=css,
                   attributes...)
end

using Random

App() do
    d = D.Dropdown("Dropdown", [randstring(5) for i in 1:100])
    kw = (; figure=(; backgroundcolor=:transparent, size=(500, 500)), axis=(; backgroundcolor=(:gray, 0.2)))
    WGLMakie.activate!(; resize_to=:parent)
    c1 = Card(scatter(1:4; kw...); width="300px", height="300px")
    c2 = Card(scatter(1:4; kw...); height="400px")
    c3 = Card(scatter(1:4; kw...); width="600px")
    c4 = Card(scatter(1:4; kw...); width="200px")
    return DOM.div(JSServe.TailwindCSS, d, D.FlexGrid(c1, c2, c3, c4))
end


App() do
    f, ax, pl = lines(cumsum(randn(1000)))
    x_val = Observable(NaN)
    vlines!(ax, x_val; color=:red)
    on(ax.scene.events.mouseposition) do mp
        w = Makie.mouseposition(ax.scene)
        x_val[] = w[1]
    end
    return DOM.div(f)
end
