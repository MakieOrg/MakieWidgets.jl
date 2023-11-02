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
    f, ax, p = scatter(1:4; markersize=40, axis=(backgroundcolor=:transparent,),
                       figure=(; backgroundcolor=:transparent, resolution=(500, 500)))
    on_click_callback = js"""(plot, index) => {
        // Which can be used to extract e.g. position or color:
        const {pos} = plot.geometry.attributes
        const x = pos.array[index*2] // everything is a flat array in JS
        const y = pos.array[index*2+1]
        // return either a string, or an HTMLNode:
        return "Point: <" + x + ", " + y + ">"
    }
    """
    # ToolTip(figurelike, js_callback; plots=plots_you_want_to_hover)
    tooltip = WGLMakie.ToolTip(f, on_click_callback; plots=p)
    button = PlayButton(1:10)
    on(button.value) do i
        p[1] = 1:i
        return autolimits!(ax)
    end
    cards = DOM.div(D.Card("A"),
                    D.Card(DOM.div(button; class="flex justify-center"); class="bg-indigo-500", width="50%"),
                    D.Card("C"),
                    ; class="flex justify-center")
    fcard = D.Card(scatter(rand(Point3f, 10)))
    return DOM.div(JSServe.TailwindCSS,
                   D.Card(DOM.div(cards, tooltip, fcard); width="50%",
                          style="background-color: rgb(226 232 240)"))
end

using WGLMakie, Makie, JSServe

function xy_data(x, y)
    r = sqrt(x^2 + y^2)
    return r == 0.0 ? 1.0f0 : (sin(r) / r)
end
App() do
    WGLMakie.activate!(; resize_to_body=true)
    N = 60

    l = range(-10; stop=10, length=N)
    z = Float32[xy_data(x, y) for x in l, y in l]

    f1, ax, p = scatter(1:4; markersize=40, axis=(backgroundcolor=:transparent,),
                        figure=(; backgroundcolor=:transparent, size=(500, 500)))
    DataInspector(ax)
    f2, ax, p = scatter(rand(Point3f, 10); axis=(scenekw=(; backgroundcolor=:transparent),),
                        figure=(; backgroundcolor=:transparent, size=(500, 500)))
    f3, ax, p = meshscatter(rand(Point3f, 10); axis=(scenekw=(; backgroundcolor=:transparent),),
                            figure=(; backgroundcolor=:transparent, size=(500, 500)))
    f4, ax, p = surface(-1 .. 1, -1 .. 1, z; colormap=:Spectral,
                        axis=(scenekw=(; backgroundcolor=:transparent),),
                        figure=(; backgroundcolor=:transparent, size=(500, 500)))
    class = "w-96 p-6 shadow-lg shadow-blue-500/50"
    cards = D.FlexGrid(D.Card(f1; class=class),
                       D.Card(f2; class=class),
                       D.Card(f3; class=class),
                       D.Card(f4; class=class);
                       class="flex justify-center")
    return DOM.div(JSServe.TailwindCSS, cards)
end
