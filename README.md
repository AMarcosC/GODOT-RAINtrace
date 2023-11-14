# GODOT-RAINtrace
Uso de algoritmo de traçado de raios baseado no GODOT-Raytrace produzido anteriormente, para o cálculo de área de contribuição de captação de chuva em edificações, baseando-se no caso geral da NBR 10844. O principal objetivo deste software é auxiliar o cálculo da área de contribuição em telhados, cobertas e fachadas de modelagem complexa e excêntrica, que não seja fielmente representada por nenhuma das fórmulas do ábaco da Figura 2 da referida NBR, e portanto se utilizando do caso geral, explicado na Figura 1 da NBR, na forma de algoritmo computacional. Neste caso, o software se utiliza de um algoritmo semelhante ao de traçado de raios, desenvolvido por mim e aplicado em outros softwares anteriores a este. A viabilidade da execução desta tarefa em computadores pessoais só é possível pelo uso de computação paralela e assíncrona desenvolvida a partir de _compute shaders_ da engine de jogos _GODOT_. Não é recomendada a execução deste software em computadores sem placa de vídeo _(graphics card)_, visto que o código paralelizado é executado utilizando tecnologias presentes nelas.

![Inteface de Usuário](/manual/UI.png)

### Testes e conformidade com a NBR 10844

O modelo tridimensional apresentado abaixo, representando uma coberta com platimbanda, onde uma das paredes é mais elevada, deve ter a sua área de contribuição calculada a partir da combinação das fórmulas (a) superfície plana horizontal, e (h) quatro superfícies planas verticais, sendo uma com maior altura, da Figura 2 da NBR 10844.

Colocar imagem

Portanto, a área de contribuição total deve ser de:

`(a) Superfície plana horizontal              --- A = a*b = 2*2 = 4 m²`
`(f) quatro superfícies planas verticais...   --- A = a*b/2 = 2*1/2 = 1 m²`
`Área de contribuição total: 5 m²`

Ou seja, a maior área de contribuição, em qualquer direção que o vento direcione a chuva, e com a chuva numa inclinação de 63,44° (Inclinação de 2:1 segundo o caso geral da norma), deve ser de 5 m² para este caso.

Executando o programa para calcular essa área em todas as direções do vento de grau em grau (0° a 359°), e utilizando, além da inclinação normativa de 63,44°, outras inclinações, obtemos os seguintes resultados:

Colocar Imagem

Como é possível observar no gráfico, a maior área obtida ao longo da curva de pontos da inclinação de 63,44° é exatamente 5 m², igualando-se ao resultado obtido utilizando a formulação da Figura 2.

É importante salientar que, por mais que seja possível utilizar este software para casos simples como foi mostrado neste exemplo, ele é voltado para casos complexos que não se enquadam em nenhum caso da Figura 2 da NBR, ou que tenha muitos detalhes ou subdivisões que aumentem muito a tarefa de computar estes vários pequenos detalhes construtivos.
