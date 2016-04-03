---
title: Урок 49 - Каскадные карты теней
---

Давайте всмотримся в тени из [урока 47](tutorial47.html):

![](/images/49/img1.jpg)

Как вы можете заметить, качество теней не высоко. Слишком пиксилизированно. Мы уже разобрались с причиной такого
эффета и назвали его *Perspective Aliasing*, представляющей собой отображение большого
числа пикселей из пространства сцены на один пиксель карты теней. Это значит что все эти пиксели будут либо в тени,
либо освещены одновременно. Другими словами, поскольку разрешение карты теней недостаточно высоко, она не может
достаточно покрыть все пространство сцены. Самый простой способ решения - это увеличить разрешение карты теней,
но это увеличит потребление памяти нашим приложением, так что этот метод не самый лучший.

Другой способ решить эту проблему - это заметить, что тени ближе к камере в плане качества куда важнее, чем тени далеко
находящихся объектов. В любом случае, объекты на расстоянии меньше по размеру, а глаза как раз фокусируются на том, что
происходит на первом плане, а остальное воспринимается как фон. Если бы мы могли использовать детализированную карту
теней для близких объектов, и другую для удаленных, то первая карта теней должна будет покрыть только небольшой
участок, то есть, уменьшая соотношение, которое мы обсудили ранее. Кароче говоря, так и работает
*Каскадные карты теней (Cascaded Shadow Mapping a.k.a CSM)*. На момент написания этого урока, CSM считается одним из лучших способов для
борьбы с Perspective Aliasing. Что же, давайте подумаем как мы могли бы это реализовать.

В целом мы собираемся разбить пирамиду обзора на несколько частей - каскадов (их не обязательно должно быть два как в
предыдущем примере). В данном уроке мы будем использовать три каскада: ближний, средний и дальний. Сам алгоритм достаточно
обобщенный, так что не составит проблем увеличить число каскадов, если понадобится. Каждый каскад будет рендериться в его
собственную карту теней. Сам алгоритм теней остаётся без изменений, за исключением того, что взятие значения глубины
из карты теней должно выбирать подходящую карту, в зависимости от растояния до зрителя. Давайте посмотрим на усеченную
пирамиду обзора:

![](/images/49/img2.png)

Как обычно, у нас есть маленькая ближняя и большая дальняя плоскости. Теперь давайте посмотрим на сцену сверху:

![](/images/49/img3.png)

Следующим шагом мы разбиваем расстояние от ближней плоскости до дальней на три части. Мы будем называть их ближней,
средней и дальней. И ещё давайте добавим направление света (стрелка справа):

![](/images/49/img4.png)

Итак, как же мы собираемся рендерить каждый каскад в отдельную карту теней? Вспомним этап теней в алгоритме карты
теней. Мы настраиваем сцену для рендера с позиции источника света. Это заключается в создании матрицы WVP с
мировыми преобразованиями объекта, преобразованиями пространства обзора для света и матрицу проекции. Так как этот
урок основывается на уроке 47, который работает с тенями направленного света, то матрица проекции будет ортогональной.
Обычно CSM используется для открытых сцен, где главный источник света это солнце, и использование направленного света
здесь естественно. Если вы посмотрите на матрицу WVP выше, то вы заметите, что первые две части (мировая и обзора)
одинаковые для всех каскадов. В конце концов, позиция объекта на сцене и параметры камеры относительно источника света
не зависят от разбиение пирамиды на каскады. Так что важна здесь только матрица проекции, поскольку она задает
область, которая будет отрендерена. А поскольку ортогональная матрица проекции задается параллелепипедом, то нам нужно
задать три различных параллелепипеда, которые будут отображены в три разных ортогональных матрицы проекции.
Все три матрицы будут использованы для получения трёх матриц WVP для рендера каждого каскада в его отдельную карту теней.

Логичнее всего было бы сделать эти рамки настолько маленькими, насколько это возможно для получения
наименьшего коэфициента отношения пикселей пространства сцены к карте теней. Для этого создадим ограничивающую
рамку для каждого каскада вдоль вектора света. Давайте добавим её к первому каскаду:

![](/images/49/img5.png)

Давайте теперь добавим ограничивающую рамку для второго каскада:

![](/images/49/img6.png)

И ещё одну для последнего каскада:

![](/images/49/img7.png)

Как вы можете заметить, из-за положения света в пространстве границы рамок слегка пересекаются, и как следствие,
некоторые пиксели будут отрендерены сразу на несколько карт теней. Но до тех пор, пока все пиксели одного каскада
находятся целиков в одной карте теней, для нас это не проблема. Выбор карты теней для вычислений в шейдере будет
основан на растоянии пикселя от самого зрителя.

Самой сложной частью алгоритма является нахождение ограничивающих рамок, которые и будут основой для
ортогональной проекции в теневом проходе. Они должны быть заданы в пространстве источника света (в котором источник
расположен в начале координат и направлен вдоль оси Z) так как проекции идут после мировых и камерных преобразований.
Параллелипипиды будут заданы своими размерами по всем трем осям и выровнены вдоль направления света - то что нужно для
проекции. Для нахождения рамок нам нужно знать как каждый каскад выглядит в пространстве света. Для этого проделаем
следующие шаги:

1. Находим восемь углов в пространстве обзора. Это не сложно, требуется лишь немного тригонометрии:

    ![](/images/49/frustum1.png)

    На изображение выше представлен произвольный каскад (так как каждый каскад является такой же усеченной пирамидой
    с таким же углом обзора, как и остальные). Заметим, что мы смотрим сверху вниз на плоскость XZ. Нам нужно найти
    X<sub>1</sub> и X<sub>2</sub>:

    ![](/images/49/calc1.png)

    ![](/images/49/calc2.png)

    Таким образом мы получаем координаты X и Z всех восьми вершин каскада в пространстве обзора. Используя
    аналогичные вычисления для вертикального угла обзора мы можем найти координату Y.

2. Теперь нам нужно преобразовать координаты каскада из пространства обзора обратно в мировое пространство.
    Предположим, что зритель расположен в мировом пространстве таким образом, что пирамида выглядит так
    (красная стрелка обозначает источник света, но пока что мы можем её проигнорировать):

    ![](/images/49/frustum2.png)

    Для того что бы перенести из мирового пространства в пространство камеры, мы умножаем вектор позиции в
    мировом пространстве на матрицу камеры (получаемую из позиции камеры и её угла поворота). Это значит, что
    если мы уже имеем координаты каскада в пространстве камеры, то мы просто умножаем их на обратную матрицу
    камеры для переноса в мировое пространство:

    ![](/images/49/calc3.png)

3. Как и любой другой объект, мы можем преобразовать координаты пирамиды из мирового пространства в пространство света.
    Вспомним, что пространство света абсолютно индентично пространству камеры, разве что вместо камеры используется
    источник света. Так как в нашем случае используется направленный свет, у которого нет позиции в пространстве, нам
    требуется только повернуть сцену таким образом, чтобы свет был направлен вдоль положительного направления оси Z.
    А положение света можно задать в начале координат пространства света (то есть, нам не нужно преобразований смещения).
    Если мы сделаем это для рисунка выше (где красная стрелка задает источник света), то каскады в пространстве света
    будут выглядить следующим образом:

    ![](/images/49/frustum3.png)

4. Наконец, получив координаты каскадов в пространстве света, нам остается только найти границы рамок. Для этого возьмем
    наибольшие и наименьшие значения компонент X/Y/Z для всех восьми вершин. Такой параллелепипед содержит значения,
    необходимые для ортогональной проекции для рендера каскада на карту теней. Получив для каждого каскада отдельную
    матрицу проекции, мы можем рендерить каждый каскад в отдельную карту. На световом этапе мы будем вычислять коэффициент
    теней выбирая карту теней ориентируясь на расстоянии от зрителя.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial49)

> ogldev_shadow_map_fbo.cpp:104

    bool CascadedShadowMapFBO::Init(unsigned int WindowWidth, unsigned int WindowHeight)
    {
          // Создаем FBO
          glGenFramebuffers(1, &m_fbo);

          // Создаем буфер глубины
          glGenTextures(ARRAY_SIZE_IN_ELEMENTS(m_shadowMap), m_shadowMap);

          for (uint i = 0 ; i < ARRAY_SIZE_IN_ELEMENTS(m_shadowMap) ; i++) {
                glBindTexture(GL_TEXTURE_2D, m_shadowMap[i]);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32, WindowWidth, WindowHeight, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_NONE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
          }

          glBindFramebuffer(GL_FRAMEBUFFER, m_fbo);
          glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_shadowMap[0], 0);

          // Отключаем запись в буфер цвета
          glDrawBuffer(GL_NONE);
          glReadBuffer(GL_NONE);

          GLenum Status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

          if (Status != GL_FRAMEBUFFER_COMPLETE) {
              printf("FB error, status: 0x%x\n", Status);
              return false;
          }

          return true;
    }


    void CascadedShadowMapFBO::BindForWriting(uint CascadeIndex)
    {
          assert(CascadeIndex < ARRAY_SIZE_IN_ELEMENTS(m_shadowMap));
          glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_fbo);
          glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_shadowMap[CascadeIndex], 0);
    }


    void CascadedShadowMapFBO::BindForReading()
    {
          glActiveTexture(CASCACDE_SHADOW_TEXTURE_UNIT0);
          glBindTexture(GL_TEXTURE_2D, m_shadowMap[0]);

          glActiveTexture(CASCACDE_SHADOW_TEXTURE_UNIT1);
          glBindTexture(GL_TEXTURE_2D, m_shadowMap[1]);

          glActiveTexture(CASCACDE_SHADOW_TEXTURE_UNIT2);
          glBindTexture(GL_TEXTURE_2D, m_shadowMap[2]);
    }

Выше описан класс *CascadedShadowMapFBO* , который является модификацией класса *ShadowMapFBO*,
используемого в предыдущих уроках. Главное отличие в том, что массив ** содержит три карты теней
- ровно столько, сколько у нас каскадов. Также приведены три основных метода для инициализации,
для привязки на запись в проходе теней и на чтение в проходе света.

> tutorial49.cpp:197

    virtual void RenderSceneCB()
    {
         for (int i = 0; i < NUM_MESHES ; i++) {
                m_meshOrientation[i].m_rotation.y += 0.5f;
          }

          m_pGameCamera->OnRender();

          ShadowMapPass();
          RenderPass();
          OgldevBackendSwapBuffers();
    }

Главная функция алгоритма CCM такая же, как и для обычного алгоритма карт теней - сначала рендерим
на карту теней, а затем используем её для вычисления света.

> tutorial49.cpp:211

    void ShadowMapPass()
    {
          CalcOrthoProjs();

          m_ShadowMapEffect.Enable();

          Pipeline p;

          // Камера помещается на позицию источника света и не меняет на протежении этого этапа
          p.SetCamera(Vector3f(0.0f, 0.0f, 0.0f), m_dirLight.Direction, Vector3f(0.0f, 1.0f, 0.0f));

          for (uint i = 0 ; i < NUM_CASCADES ; i++) {
                // Привязываем и очищаем текущий каскад
                m_csmFBO.BindForWriting(i);
                glClear(GL_DEPTH_BUFFER_BIT);

                p.SetOrthographicProj(m_shadowOrthoProjInfo[i]);

                for (int i = 0; i < NUM_MESHES ; i++) {
                      p.Orient(m_meshOrientation[i]);
                      m_ShadowMapEffect.SetWVP(p.GetWVOrthoPTrans());
                      m_mesh.Render();
                }
          }

          glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

В этапе теней добавлена парочка изменений, которые заслуживают внимания. Первое, вызов *CalOrthoProjs()* в начале этапа.
Эта функция отвечает за вычисление ограничивающих рамок, используемых для ортогональной проекции. Следующее отличие это
цикл по каскадом. Каждый из них по-отдельности должен быть привязан на запись, очищен и отрендерен. Каждый каскад имеет
свою проекцию в массиве *m_shadowOrthoProjInfo* (который заполняет CalcOrthoProjs). Так как мы не знаем в какой каскад
попадет каждый меш (а их может быть больше одного), то мы вынуждены рендерить всю сцену для каждого каскада.

> tutorial49.cpp:238

    void RenderPass()
    {
          glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

          m_LightingTech.Enable();

          m_LightingTech.SetEyeWorldPos(m_pGameCamera->GetPos());

          m_csmFBO.BindForReading();

          Pipeline p;
          p.Orient(m_quad.GetOrientation());
          p.SetCamera(Vector3f(0.0f, 0.0f, 0.0f), m_dirLight.Direction, Vector3f(0.0f, 1.0f, 0.0f));

          for (uint i = 0 ; i < NUM_CASCADES ; i++) {
                p.SetOrthographicProj(m_shadowOrthoProjInfo[i]);
                m_LightingTech.SetLightWVP(i, p.GetWVOrthoPTrans());
          }

          p.SetCamera(m_pGameCamera->GetPos(), m_pGameCamera->GetTarget(), m_pGameCamera->GetUp());
          p.SetPerspectiveProj(m_persProjInfo);
          m_LightingTech.SetWVP(p.GetWVPTrans());
          m_LightingTech.SetWorldMatrix(p.GetWorldTrans());
          m_pGroundTex->Bind(COLOR_TEXTURE_UNIT);

          m_quad.Render();

          for (int i = 0; i < NUM_MESHES ; i++) {
                p.Orient(m_meshOrientation[i]);
                m_LightingTech.SetWVP(p.GetWVPTrans());
                m_LightingTech.SetWorldMatrix(p.GetWorldTrans());
                m_mesh.Render();
          }
    }

Единственное отличие в проходе света в том, что для света вместо одной матрицы WVP их стало три. Они отличаются
только проекциями. Мы получаем их в цикле в середине этапа.

> tutorial49.cpp:80

    m_cascadeEnd[0] = m_persProjInfo.zNear;
    m_cascadeEnd[1] = 25.0f,
    m_cascadeEnd[2] = 90.0f,
    m_cascadeEnd[3] = m_persProjInfo.zFar;

Перед тем как мы займемся вычислением ортогональной проекции, нам следует обратить внимание на массив *m_cascadeEnd*
(который инициализируется в конструкторе). Этот массив задает каскады записывая значения ближней и дальней Z в первый и
последний слот соответственно и границы каскадов посередине. Таким образом первый каскад заканчивается в значении из
первого слота, второй из второго и третий из последнего. А значение ближней Z плоскости в первом слоте позже поможет
упростить вычисления.

> tutorial49.cpp:317

    void CalcOrthoProjs()
    {
          Pipeline p;

          // Получаем обратные преобразования
          p.SetCamera(m_pGameCamera->GetPos(), m_pGameCamera->GetTarget(), m_pGameCamera->GetUp());
          Matrix4f Cam = p.GetViewTrans();
          Matrix4f CamInv = Cam.Inverse();

          // Получаем преобразования света
          p.SetCamera(Vector3f(0.0f, 0.0f, 0.0f), m_dirLight.Direction, Vector3f(0.0f, 1.0f, 0.0f));
          Matrix4f LightM = p.GetViewTrans();

          float ar = m_persProjInfo.Height / m_persProjInfo.Width;
          float tanHalfHFOV = tanf(ToRadian(m_persProjInfo.FOV / 2.0f));
          float tanHalfVFOV = tanf(ToRadian((m_persProjInfo.FOV * ar) / 2.0f));

          for (uint i = 0 ; i < NUM_CASCADES ; i++) {
                float xn = m_cascadeEnd[i]     * tanHalfHFOV;
                float xf = m_cascadeEnd[i + 1] * tanHalfHFOV;
                float yn = m_cascadeEnd[i]     * tanHalfVFOV;
                float yf = m_cascadeEnd[i + 1] * tanHalfVFOV;

                Vector4f frustumCorners[NUM_FRUSTUM_CORNERS] = {
                      // Ближняя плоскость
                      Vector4f(xn,   yn, m_cascadeEnd[i], 1.0),
                      Vector4f(-xn,  yn, m_cascadeEnd[i], 1.0),
                      Vector4f(xn,  -yn, m_cascadeEnd[i], 1.0),
                      Vector4f(-xn, -yn, m_cascadeEnd[i], 1.0),

                      // Дальняя плоскость
                      Vector4f(xf,   yf, m_cascadeEnd[i + 1], 1.0),
                      Vector4f(-xf,  yf, m_cascadeEnd[i + 1], 1.0),
                      Vector4f(xf,  -yf, m_cascadeEnd[i + 1], 1.0),
                      Vector4f(-xf, -yf, m_cascadeEnd[i + 1], 1.0)
                };

Выше мы видим первый шаг из блока теории о вычислении ортогональной проекции для каскада. Массив *frustumCorners*
заполнен восемью вершинами каскада в пространсве экрана. Заметим, что так задан только горизонтальный угол обзора,
то вертикальный мы вычисляем вручную (например, если горизонтальный угол обзора равен 90&deg;, а размеры окна
1000x500, то вертикальный улог обзора будет равен 45&deg;).

                Vector4f frustumCornersL[NUM_FRUSTUM_CORNERS];

                float minX = std::numeric_limits<float>::max();
                float maxX = std::numeric_limits<float>::min();
                float minY = std::numeric_limits<float>::max();
                float maxY = std::numeric_limits<float>::min();
                float minZ = std::numeric_limits<float>::max();
                float maxZ = std::numeric_limits<float>::min();

                for (uint j = 0 ; j < NUM_FRUSTUM_CORNERS ; j++) {
                      // Преобразуем координаты усеченоой пирамиды из пространства камеры в мировое пространство
                      Vector4f vW = CamInv * frustumCorners[j];
                      // И ещё раз из мирового в пространство света
                      frustumCornersL[j] = LightM * vW;

                      minX = min(minX, frustumCornersL[j].x);
                      maxX = max(maxX, frustumCornersL[j].x);
                      minY = min(minY, frustumCornersL[j].y);
                      maxY = max(maxY, frustumCornersL[j].y);
                      minZ = min(minZ, frustumCornersL[j].z);
                      maxZ = max(maxZ, frustumCornersL[j].z);
               }

Код выше выполняет шаги со #2 по #4. Каждая вершина каскада домнажается на обратную матрицу преобразований
для перевода в мировое пространство. А после она домнажается на преобразования света для перевода в его
пространство. А после мы несколько раз используем функции min/max для вычисления ограничивающей рамки
каскада в пространстве света.

                m_shadowOrthoProjInfo[i].r = maxX;
                m_shadowOrthoProjInfo[i].l = minX;
                m_shadowOrthoProjInfo[i].b = minY;
                m_shadowOrthoProjInfo[i].t = maxY;
                m_shadowOrthoProjInfo[i].f = maxZ;
                m_shadowOrthoProjInfo[i].n = minZ;
          }
    }


Текущая запись в массиве *m_shadowOrthoProjInfo* заполняется используя значения обрамляющей рамки.

> csm.vs

    #version 330

    layout (location = 0) in vec3 Position;
    layout (location = 1) in vec2 TexCoord;
    layout (location = 2) in vec3 Normal;

    uniform mat4 gWVP;

    void main()
    {
          gl_Position = gWVP * vec4(Position, 1.0);
    }

> csm.fs

    #version 330

    void main()
    {
    }

Ничего нового в вершинном и фрагментном шейдерах этапа теней. Мы по прежнему просто рендерим глубину.

> lighting.vs

    #version 330

    layout (location = 0) in vec3 Position;
    layout (location = 1) in vec2 TexCoord;
    layout (location = 2) in vec3 Normal;

    const int NUM_CASCADES = 3;

    uniform mat4 gWVP;
    uniform mat4 gLightWVP[NUM_CASCADES];
    uniform mat4 gWorld;

    out vec4 LightSpacePos[NUM_CASCADES];
    out float ClipSpacePosZ;
    out vec2 TexCoord0;
    out vec3 Normal0;
    out vec3 WorldPos0;

    void main()
    {
          vec4 Pos = vec4(Position, 1.0);

          gl_Position = gWVP * Pos;

          for (int i = 0 ; i < NUM_CASCADES ; i++) {
                LightSpacePos[i] = gLightWVP[i] * Pos;
          }

          ClipSpacePosZ = gl_Position.z;
          TexCoord0     = TexCoord;
          Normal0       = (gWorld * vec4(Normal, 0.0)).xyz;
          WorldPos0     = (gWorld * vec4(Position, 1.0)).xyz;
    }

Давайте расмотрим изменения в вершинном шейдере светового этапа. Вместо передачи одной
вершины в пространстве света их теперь три - по одной для каждого каскада. Так же мы собираемся
выбирать нужную в фрагментном шейдере. В дальнейшем вы можете захотеть оптимизировать это, но для
обучающих целей я решил что и так пойдет. Не забывайте, что вы не можете выбрать каскад в вершинном
шейдере так как треугольник может располагаться сразу в нескольких каскадах. Итого, у нас есть матрицы
WVP и три вершины пространства света. Кроме того, мы также передаем значение Z в пространстве клиппера.
Она пригодится нам при выборе каскада в фрагментном шейдере. Заметим, что она вычислена в мировом
пространстве, а не в пространстве света.

> lighting.fs

    const int NUM_CASCADES = 3;

    in vec4 LightSpacePos[NUM_CASCADES];
    in float ClipSpacePosZ;

    uniform sampler2D gShadowMap[NUM_CASCADES];
    uniform float gCascadeEndClipSpace[NUM_CASCADES];

Фрагментный шейдер прохода света содержит некоторые дополнения в основной секции. На вход мы получаем
три вершины в пространстве света, которые вычислил вершинный шейдер, а так же значение Z в пространстве
клиппера. Вместо одной карты теней их теперь три. Кроме того, приложение должно передавать конец каждого
каскада в пространстве клиппера. Чуть позже мы увидим как оно вычисляется. А пока просто предположим что
он уже есть.

    float CalcShadowFactor(int CascadeIndex, vec4 LightSpacePos)
    {
          vec3 ProjCoords = LightSpacePos.xyz / LightSpacePos.w;

          vec2 UVCoords;
          UVCoords.x = 0.5 * ProjCoords.x + 0.5;
          UVCoords.y = 0.5 * ProjCoords.y + 0.5;

          float z = 0.5 * ProjCoords.z + 0.5;
          float Depth = texture(gShadowMap[CascadeIndex], UVCoords).x;

          if (Depth < z + 0.00001)
                return 0.5;
          else
                return 1.0;
    }

    void main()
    {
          float ShadowFactor = 0.0;

          for (int i = 0 ; i < NUM_CASCADES ; i++) {
                if (ClipSpacePosZ <= gCascadeEndClipSpace[i]) {
                      ShadowFactor = CalcShadowFactor(i, LightSpacePos[i]);
                      break;
                }
         }
         ...

Для того что бы для текущего пикслея выбрать подходящий каскад мы передаем uniform-массив
*gCascadeEndClipSpace* и сравниваем Z компоненту координаты в пространстве клиппера с
каждой записью в массиве. Массив отсортирован по возрастанию удаленности. Мы останавливаемся как
только мы нашли запись, значение которой больше или равно текущей компоненте Z. Затем мы вызываем
*CalcShadowFactor()* и передаем туда индекс найденного каскада. Единственное отличие в этой
функции в том, что получаем значение глубины из той карты теней, индекс которой равен найденному.
Остальное без изменений.

> tutorial49.cpp:134

        for (uint i = 0 ; i < NUM_CASCADES ; i++) {
              Matrix4f Proj;
              Proj.InitPersProjTransform(m_persProjInfo);
              Vector4f vView(0.0f, 0.0f, m_cascadeEnd[i + 1], 1.0f);
              Vector4f vClip = Proj * vView;
              m_LightingTech.SetCascadeEndClipSpace(i, vClip.z);
        }

Последний кусок мозайки - это подготовка значений для массива *gCascadeEndClipSpace*. Для этого
возьмем координаты (0, 0, Z), где Z это конец каскада в пространстве камеры. Для перевода значения
в пространство экрана мы просто используем обычную проекции перспективы. Такая операция проводится
для каждого каскада для поиска границы в пространстве клиппера.

Если вы посмотрите код урока, то вы увидите, что я добавил индикатор границы каскадов назначив
каждому из них свой цвет (красный, зеленый или синий). Это очень полезно при отладке, так как вы
явно можете видеть границы каждого каскада. С алгоритмом CSM и цветным индикатором сцена выглядит
как-то так:

![](/images/49/final.jpg)
