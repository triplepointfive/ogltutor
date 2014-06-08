---
title: Урок 07 - Вращение
---
<a href="http://ogldev.atspace.co.uk/www/tutorial07/tutorial07.html"><h2>Теоретическое введение</h2></a>

<p>Следующий на очереди трансформаций - это вращение, то есть, берется угол и точка, которую мы хотим вращать относительно оси. Для этого всегда будут меняться 2 координаты из 3 (X, Y и Z), а одна останется без изменений. Это значит, что путь будет лежать на одной из 3-х основных плоскостей: XY (когда вращение вокруг Z), YZ (повороты относительно X) и XZ (для Y оси). Можно подобрать преобразования для вращения вокруг произвольной оси, но они довольно сложные и пока что нам не нужны.</p>
<p>Давайте определим задачу в общих чертах. Сосредоточимся на следующей диаграмме:</p>
<img style="width: 816px; height: 650px;" alt="" src="/images/t7_rotation.png"><br>
<p>Мы хотим двигаться по окружности из (x<sub>1,</sub>y<sub>1</sub>) в (x<sub>2,</sub>y<sub>2</sub>). Другими словами, мы хотим повернуть точку (x<sub>1,</sub>y<sub>1</sub>) на угол <span style="font-family: Symbol;">a<sub>2</sub></span>. Предположим, что радиус окружности равен 1. Это означает следующее:</p>
x<sub>1</sub>=cos(<span style="font-family: Symbol;">a<sub>1</sub></span>)<span style="font-family: Symbol;"><sub></sub></span><br> 
y<sub>1</sub>=sin(<span style="font-family: Symbol;">a<sub>1</sub></span>)<span style="font-family: Symbol;"></span><br>
x<sub>2</sub>=cos(<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;">+</span><span style="font-family: Symbol;"></span><span style="font-family: Symbol;">a<sub>2</sub></span>)<span style="font-family: Symbol;"></span><br>
y<sub>2</sub>=sin(<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;">+</span><span style="font-family: Symbol;">a<sub>2</sub></span>)<br>
<p>Мы будем использовать следующие тригонометрические тождества для нахождения x<sub>2</sub> и y<sub>2</sub>:</p>
cos(<span style="font-family: Symbol;">a+<span style="font-family: Symbol;">b) =<span style="font-family: Times New Roman,Times,serif;"></span></span></span> cos<span style="font-family: Symbol;">a</span>cos<span style="font-family: Symbol;"><span style="font-family: Symbol;">b </span></span>- sin<span style="font-family: Symbol;">a</span>sin<span style="font-family: Symbol;"><span style="font-family: Symbol;">b</span></span><br>
sin(<span style="font-family: Symbol;">a+<span style="font-family: Symbol;">b) =<span style="font-family: Times New Roman,Times,serif;"></span></span></span> sin<span style="font-family: Symbol;">a</span>cos<span style="font-family: Symbol;"><span style="font-family: Symbol;">b</span></span>+cos<span style="font-family: Symbol;">a</span>sin<span style="font-family: Symbol;"><span style="font-family: Symbol;">b</span></span><br>
<p>Используя формулы выше, можем написать:</p>
x<sub>2</sub>=cos(<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;">+</span><span style="font-family: Symbol;"></span><span style="font-family: Symbol;">a<sub>2</sub></span>)
<span style="font-family: Symbol;">= </span>cos<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;"></span>cos<span style="font-family: Symbol;">a<sub>2 </sub></span><span style="font-family: Symbol;"><span style="font-family: Symbol;"></span></span>- sin<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;"></span><span style="font-family: Symbol;"></span>sin<span style="font-family: Symbol;">a<sub>2</sub></span>
<span style="font-family: Symbol;">= </span>x<sub>1</sub>cos<span style="font-family: Symbol;">a<sub>2 </sub></span><span style="font-family: Symbol;"><span style="font-family: Symbol;"></span></span>-
y<sub>1</sub>sin<span style="font-family: Symbol;">a<sub>2<br>
</sub></span>y<sub>2</sub>=sin(<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;">+</span><span style="font-family: Symbol;">a<sub>2</sub></span>) = sin<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;"></span>cos<span style="font-family: Symbol;">a<sub>2 </sub></span><span style="font-family: Symbol;">+</span> cos<span style="font-family: Symbol;">a<sub>1</sub></span><span style="font-family: Symbol;"></span><span style="font-family: Symbol;"></span>sin<span style="font-family: Symbol;">a<sub>2</sub></span>
<span style="font-family: Symbol;">= </span>y<sub>1</sub>cos<span style="font-family: Symbol;">a<sub>2 </sub></span><span style="font-family: Symbol;"><span style="font-family: Symbol;"></span></span>+
x<sub>1</sub>sin<span style="font-family: Symbol;">a<sub>2</sub></span><br>
<p>В диаграмме мы смотрим на плоскость XY, а ось Z - это точка. Если X&amp;Y части 4-вектора, тогда уравнения выше можно записать в форме матрицы (не затрагивая Z&amp;W):</p>
<img style="width: 885px; height: 275px;" alt="" src="/images/t7_07_01.png">
<p>Если мы хотим задать вращение для Y и X осей, то выражения будут похожи, а вот матрицы устроены слегка по другому. Вот матрица для вращения вокруг Y оси:</p>
<img style="width: 885px; height: 275px;" alt="" src="/images/t7_07_02.png">
<p>И матрица вращения вокруг X оси:</p>
<img style="width: 885px; height: 275px;" alt="" src="/images/t7_07_03.png">
  
  
<a href="https://github.com/triplepointfive/ogldev/tree/master/tutorial07"><h2>Прямиком к коду!</h2></a>
<p>Изменения кода в этом уроке очень малы. Мы только изменяем значения единственной матрицы преобразований.</p>

<pre><code>World.m[0][0]=cosf(Scale); World.m[0][1]=-sinf(Scale); World.m[0][2]=0.0f; World.m[0][3]=0.0f;
World.m[1][0]=sinf(Scale); World.m[1][1]=cosf(Scale);  World.m[1][2]=0.0f; World.m[1][3]=0.0f;
World.m[2][0]=0.0f;        World.m[2][1]=0.0f;         World.m[2][2]=1.0f; World.m[2][3]=0.0f;
World.m[3][0]=0.0f;        World.m[3][1]=0.0f;         World.m[3][2]=0.0f; World.m[3][3]=1.0f;</code></pre>

<p>Легко заметить, что мы задали вращение вокруг Z оси. Вы можете попробовать вращение вокруг других осей, но мне кажется, что без настоящей проекции из 3D в 2D другие типы вращения будут выглядеть немного странно. Мы их реализуем в классе полноценного конвейера в следующих уроках.</p>
