##############################################################
#                   ALGORITMO MEMÉTICO 
##############################################################

using Random

include("../algoritmos-geneticos/generar-cromosoma.jl")
include("../algoritmos-geneticos/torneo-binario.jl")
include("../utils/distancias.jl")
include("../utils/funcion-objetivo.jl")
include("busqueda-local.jl")
"""
    AuxCrucePorIndices(i,j,g, FunciónCruce)
Función auxiliar para ahorrarse el cruce si i==j
"""
function AuxCrucePorIndices(i,j,g, FunciónCruce)
    if i == j 
        return g[i], g[i]
    else 
        return FunciónCruce(g[i], g[j])
    end
end
"""
    Memetico(     evaluaciones_máximas_FE, 
                    numero_cromosomas_por_generación, 
                    probabilidad_cruce,
                    probabilidad_mutación, 
                    tamaño_cromosoma, 
                    función_evaluación, 
                    función_cruce,
                    función_mutación,
                    porcentaje_cromosomas_busqueda_local,
                    funcion_selección_índices_para_busqueda_local, 
                    numero_generaciones_aplicar_bl = 10,
    ) 
    Algoritmo genético generacional, tras las iteraciones convenientes devuelve el cromosoma mejor y su función de valuación 
"""
function Memetico(   evaluaciones_máximas_FE, 
                numero_cromosomas_por_generación, 
                probabilidad_cruce,
                probabilidad_mutación, 
                tamaño_cromosoma, 
                función_evaluación, 
                función_cruce,
                función_mutación,
                porcentaje_cromosomas_busqueda_local,
                funcion_selección_índices_para_busqueda_local, 
                numero_generaciones_aplicar_bl = 10,
                )
    # Generamos la primera generación 
    generación = [GeneraCromosoma(tamaño_cromosoma, 0.1) for i in 1:numero_cromosomas_por_generación]
    evaluaciones_función_evaluación = map(x -> función_evaluación(x), generación)
    

    # --- Cálculo de valores auxiliares ---
    # Mitad población 
    M = floor(Int, numero_cromosomas_por_generación/2)
    ### Cruce 
    # Número de parejas a cruzar
    numero_cruces = round(Int, probabilidad_cruce* numero_cromosomas_por_generación/2)
    permutaciones = randperm(M)
    parejas_a_cruzar = permutaciones[1:numero_cruces]
    parejas_que_no_se_cruzan = permutaciones[(numero_cruces+1):M]
    # Índices de las parejas que se van a cruzar 
    índices_cruce = [
        [2*i-1, 2*i] for i in parejas_a_cruzar
    ]
    # Indice de los elementos que no se cruzan
    índices_no_cruce = vcat([
        2*i-1 for i in parejas_que_no_se_cruzan
    ],[
        2*i for i in parejas_que_no_se_cruzan
    ])
    ### Mutación 
    cantidad_cromosomas_a_mutar = round(Int, probabilidad_mutación* numero_cromosomas_por_generación)
    índices_a_mutar = randperm(M)[1:cantidad_cromosomas_a_mutar]

    # Variable que acumula el número de evaluaciones de la función de evaluación 
    evaluaciones = numero_cromosomas_por_generación
    # Array que contendrá a los elementos seleccionados
    Seleccionados = generación
    numero_generacion = 1
    while evaluaciones < evaluaciones_máximas_FE
        # Paso 1: Selección (torneo binario)
        índices_seleccionados = TorneoBinario(evaluaciones_función_evaluación, numero_cromosomas_por_generación)

        # Paso 2: Cruce 
        Seleccionados = [
            x
            for v in índices_cruce
                # Devuelve dos elementos del cruce
                for x in 
                AuxCrucePorIndices(
                    índices_seleccionados[v[1]],
                    índices_seleccionados[v[2]],
                    generación,
                    función_cruce
                )  
        ]
        Seleccionados = vcat(Seleccionados, [generación[i] for i in índices_no_cruce])

        # Paso 3: Mutación 
        for i in índices_a_mutar
            Seleccionados[i] = función_mutación(Seleccionados[i])
        end
        # Paso 4: Reemplazo 
        # Calculamos mejor cromosoma generación anterior
        índice_mejor = argmax(evaluaciones_función_evaluación)
        mejor_cromosa = generación[índice_mejor]
        evaluación_mejor_cromosoma = evaluaciones_función_evaluación[índice_mejor]

        generación = copy(Seleccionados) # Por tratarse de algoritmo generacional se reemplaza totalmente la población   
        # Calculas la evaluación de la generación nueva
        evaluaciones_función_evaluación = map(x -> función_evaluación(x), generación)
        evaluaciones += numero_cromosomas_por_generación 
     
        # para mantener el elitismo si no está el mejor de la generación lo añadimos
        if !(mejor_cromosa in generación)
            índice_peor = argmin(evaluaciones_función_evaluación)
            generación[índice_peor] = mejor_cromosa
            evaluaciones_función_evaluación[índice_peor] = evaluación_mejor_cromosoma
        end
        numero_generacion += 1
        
        # Paso 5: se comprueba si hay que aplicar la búsqueda local 
        if(numero_generacion % numero_generaciones_aplicar_bl == 0)
            for i in funcion_selección_índices_para_busqueda_local(numero_cromosomas_por_generación, 
                porcentaje_cromosomas_busqueda_local,
                evaluaciones_función_evaluación)
                generación[i], evaluaciones_función_evaluación[i] = PrimeroMejor(generación[i],
                                2*tamaño_cromosoma,
                                función_evaluación)
                evaluaciones += 2*tamaño_cromosoma
            end
        end 
    end

    # Devolvemos el mejor cromosoma encontrado
    índice_mejor = argmax(evaluaciones_función_evaluación)
    evaluación_mejor = evaluaciones_función_evaluación[índice_mejor]
    mejor_cromosa = generación[índice_mejor]
    return mejor_cromosa, evaluación_mejor  
end

function Memetico_LearnerOneNN(data::Matrix{<:Real},labels, 
    evaluaciones_máximas_FE, 
    numero_cromosomas_por_generación, 
    probabilidad_cruce,
    probabilidad_mutación, 
    tamaño_cromosoma, 
    función_cruce,
    función_mutación,
    porcentaje_cromosomas_busqueda_local,
    funcion_selección_índices_para_busqueda_local, 
    numero_generaciones_aplicar_bl = 10,
    )
     # Creamos función objetivo 
    a = 0.5
    umbral_tasa_reduccion = 0.1
    función_evaluación = CrearFuncionObjetivo(data, labels, a, umbral_tasa_reduccion )
    
    # Buscamos pesos de acorde al algoritmo Memetico
    w, f_w = Memetico(evaluaciones_máximas_FE, 
                        numero_cromosomas_por_generación, 
                        probabilidad_cruce,
                        probabilidad_mutación, 
                        tamaño_cromosoma, 
                        función_evaluación, 
                        función_cruce,
                        función_mutación,
                        porcentaje_cromosomas_busqueda_local,
                        funcion_selección_índices_para_busqueda_local, 
                        numero_generaciones_aplicar_bl,
                        )
    
    return WeightedLearnerEuclideanOneNN(w, data, labels), f_w, w

end