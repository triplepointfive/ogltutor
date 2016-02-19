---
title: Урок 48 - Пользовательский интерфейс с Ant Tweak Bar
---

В этом уроке мы на время собираемся покинуть 3D и сконцентрировать наше внимание
на добавлении чего-то полезного и практичного для наших программ. Мы научимся создавать
пользовательский интерфейс, который поможет в настройке различных значений.
Библиотека, которую мы собираемся использовать, называется *Ant Tweak Bar* (или ATB),
которая расположена на [anttweakbar.sourceforge.net](http://anttweakbar.sourceforge.net/).
Существует немало настроек, и если вы захотите, то найдете гору обсуждений и мнений
по поводу каждой. Кроме OpenGL, ATB также поддерживает DirectX 9/10/11, поэтому
если вы хотите, что бы ваш интерфейс был портируемым, то это большое преимущество.
Библиотека кажется мне очень удобной и легкой в освоении. И я надеюсь вы разделите
это мнение. Ну что ж, приступим.

**<font color='red'>
Важно: только когда я уже заканчивал этот урок, я заметил, что ATB больше не разрабатывается. Официальный сайт ещё жив,
но автор предупреждает, что больше не будет активно его поддерживать. После небольших размышлений, я всё-таки решил опубликовать
этот урок. Библиотека для меня оказалась крайне удобной и я продолжу её использовать. Если вы ищите что-то подобное по
функционалу, но обязательно находящееся в активной разработке, то можете поискать альтернативу, хотя я считаю, что большинству
должно хватить и того, что уже есть. Поскольку это открытое программное обеспечение, то всегда есть шанс найти нового разработчика.
</font>**

### Установка

Первое что нам нужно сделать - это установить ATB. Вы можете скачать [zip архив](https://sourceforge.net/projects/anttweakbar/files/latest/download?source=dlp)
с сайта ATB (на момент публикации этого урока версию 1.6), который содержит почти всё что вам нужно,
либо используйте файлы, которые я прикладываю ко всем урокам. Если вы пойдете путем с сайтом, то
распакуйте архив и переложите файл *AntTweakBar.h* из католога *include* в тот католог, в котором
он будет виден проекту. На Linux я бы рекомендовал положить его в /usr/local/include (потребуется
доступ от суперпользователя). В пакете с уроками этот файл находится в катологе Include/ATB.

Теперь о файлах библиотеки.

Если вы пользуетесь Windows, то ничего сложного. Официальный архив содержит каталог lib с файлами
AntTweakBar.dll и AntTweakBar.lib (и ещё одна такая же пара для архитектуры 64). Потребуется добавить
lib файл в проект на стадии линковки, а dll файл должен быть доступным для исполняемого файла в
локальный директории, либо в катологе Windows\System32. На Linux потребуется зайти в католог src
и выполнить команду *make* для того, что бы собрать библиотеку. В результате получатся файлы
libAntTweakBar.a, libAntTweakBar.so и libAntTweakBar.so.1. Я рекомендую скопировать эти файлы в
каталог /usr/local/lib и сделать их доступными для всех. Архив с исходным кодом для этого урока
содержит всё необходимое для обеих систем.

### Интеграция

Что бы начать использовать ATB добавте в ваш код следующий заголовочный файл:

    #include <AntTweakBar.h>

Если вы используете мой проект Netbeans, то каталог Include/ATB уже добавлен в качестве
источника заголовочных файлов. В противном случае убедитесь, что система сборки видит этот файл.

Для линковки с библиотекой:
- Windows: добавьте *AntTweakBar.lib* в ваш проект .
- Linux: добавьте *-lAntTweakBar* в систему сборки, а так же проверьте, что сами файлы находятся в /usr/local/lib.

Ещё раз напомню, что если вы используете мои проекты Visual Studio или Netbeans, то вся работа уже сделана за вас.

### Инициализация

Для инициализации ATB понадобится вызов:

    TwInit(TW_OPENGL, NULL);

а для случая с Core Profile используйте:

    TwInit(TW_OPENGL_CORE, NULL);

Для этого урока я создал класс-обертку над ATB, который инкапсулирует часть функционала
библиотеки и немного упрощает интеграцию (этот класс находится в каталоге Common).
Для инициализации ATB с помощью класса используйте код наподобии:

    ATB m_atb;
    if (!m_atb.Init()) {
        // error
        return false;
    }

### Обработка Событий

ATB предоставляет целый набор разнообразных виджетов. В некоторых вы можете просто вводить новые значения. А есть и более
сложные, где можно использовать мышку для изменения значений. Как следствие, ATB должен получать события клавиатуры и мыши.
Для этой цели используются несколько коллбэков, и для каждой графической библиотеки (glut, glfw, SDL, ...) ATB предоставляет
свой набор. Если ваш фреймворк использует одну из этих библиотек, то вы можете просто вызывать каллбэки ATB внутри
собственных. Пример приведен на сайте ATB. Поскольку OGLDEV поддерживает как glut так и glfw, я покажу как я интегрировал
каллбэки в мой фреймворк таким образом, что обе библиотеки поддерживаются единым образом. Посмотрите на следующие функции
из класса ATB:

    bool ATB::KeyboardCB(OGLDEV_KEY OgldevKey)
    {
          int ATBKey = OgldevKeyToATBKey(OgldevKey);

          if (ATBKey == TW_KEY_LAST) {
                return false;
          }

          return (TwKeyPressed(ATBKey, TW_KMOD_NONE) == 1);
    }


    bool ATB::PassiveMouseCB(int x, int y)
    {
          return (TwMouseMotion(x, y) == 1);
    }


    bool ATB::MouseCB(OGLDEV_MOUSE Button, OGLDEV_KEY_STATE State, int x, int y)
    {
          TwMouseButtonID btn = (Button == OGLDEV_MOUSE_BUTTON_LEFT) ? TW_MOUSE_LEFT : TW_MOUSE_RIGHT;
          TwMouseAction ma = (State == OGLDEV_KEY_STATE_PRESS) ? TW_MOUSE_PRESSED : TW_MOUSE_RELEASED;

          return (TwMouseButton(ma, btn) == 1);
    }

По сути эти функции - обертки над каллбэками ATB. Они переводят внутренние типы OGLDEV в типы ATB и
передают их дальше в ATB. Функции возвращают true если ATB обработал событие (и можно просто
проигнорировать) и false если нет (так что стоит обратить на это событие внимание). Вот пример того
как я добавил эти функции в каллбэки этого урока:

    virtual void KeyboardCB(OGLDEV_KEY OgldevKey, OGLDEV_KEY_STATE OgldevKeyState)
    {
          if (OgldevKeyState == OGLDEV_KEY_STATE_PRESS) {
                if (m_atb.KeyboardCB(OgldevKey)) {
                      return;
                }
          }

          switch (OgldevKey) {
             .
             .
             .
              default:
                     m_pGameCamera->OnKeyboard(OgldevKey);
          }
    }


    virtual void PassiveMouseCB(int x, int y)
    {
           if (!m_atb.PassiveMouseCB(x, y)) {
                  m_pGameCamera->OnMouse(x, y);
           }
    }


    virtual void MouseCB(OGLDEV_MOUSE Button, OGLDEV_KEY_STATE State, int x, int y)
    {
           m_atb.MouseCB(Button, State, x, y);
    }

Если вы не знакомы с фреймворком OGLDEV, то код выше, возможно, не имеет для вас никакого смысла,
поэтому обязательно ознакомтесь с предыдущими уроками, что бы понять как всё устроено.
Каждый урок - это всего лишь класс, который наследует *ICallbacks* и *OgldevApp*. ICallbacks
предоставляет (не удивительно) каллбэки, вызываемые бэкендом (glut или glfw). Сначала мы
передаём события ATB, и если он их не обработал, то передаём их приложению (конкретно объекту - камере).

### Создание интерфейса

Вам понадобится создать как минимум один экземпляр класса *TwNewBar*, представляющего
собой окно с набором виджетов, позволяющих ATB взаимодействовать с приложением:

    TwBar *bar = TwNewBar("OGLDEV");

Строка в скобках - это название окна.

### Отрисовка интерфейса

In order for the tweak bar to appear in your OpenGL window there must be a call present
to the TwDraw() function in the render loop. The ATB website provides the following
generic render loop as an example:

    // главный цикл
    while( ... )
    {
          // очистка буферов
          // обновление отображения и камеры
          // обновление сцены
          // отрисовка сцены

          TwDraw();  // отрисовка интерфейса(ов)

          // показ/смена буфера кадра
    } // конец главного цикла

Я поместил вызов *TwDraw()* в начале функции *OgldevBackendSwapBuffers()* (ogldev_backend.cpp:97).
Эта функция вызывается каждый раз в конце главного цикла рендера и отличное
место для встраивания TwDraw() в фреймворк.

### Добавление виджетов

Всё что было выше необходимо только для того, что бы иметь работоспосоный ATB в вашем приложении.
Сейчас ATB должен выглядеть как-то так:

![](/images/48/atb1.jpg)

Начиная с этого момента нам нужно добавлять виджеты и связывать их с нашим приложением
что бы мы могли настраивать параметры в нашем коде.

Давайте добавим выпадающий список. В этом уроке я буду использовать его для выбора меша
для отобращения. Для того, что бы ATB мог создать список доступных элементов, я буду
использовать структуру *TwEnumVal*, предоставляемую самой библиотекой.
Эта структура состоит из пар из целого числа и строки. Число является идентификатором
для элементов списка, а строка их названием, которое и будет отображаться.
После создания списка в виде массива с элементами типа *TwEnumVal*, мы создаем объект
*TwType* используя функцию *TwDefineEnum*. TwType является перечислением для некоторых
простых типом, понимаемых ATB (цвет, вектора и т.д.), но так же есть поддержка
пользовательских типов. Когда TwType уже готов, мы можем использовать *TwAddVarRW* для его
присоединения к интерфейсу. *TwAddVarRW()* так же принимает адрес целого числа, куда ATB
сможет поместить текущее выбранное значение. А мы уже можем использовать это число
как пожелаем (в нашем случае отображать выбранный меш).

    // Создаем внутреннее перечисление с именами мешей
    typedef enum { BUDDHA, BUNNY, DRAGON } MESH_TYPE;
    // Переменная с текущим значением - она будет обновлена ATB
    MESH_TYPE m_currentMesh = BUDDHA;
    // Массив с элементами выпадающего списка
    TwEnumVal Meshes[] = { {BUDDHA, "Buddha"}, {BUNNY, "Bunny"}, {DRAGON, "Dragon"}};
    // ATB переменная для массива
    TwType MeshTwType = TwDefineEnum("MeshType", Meshes, 3);
    // Добавляем к интерфейсу
    TwAddVarRW(bar, "Mesh", MeshTwType, &m_currentMesh, NULL);

В результате должно получиться что-то в стиле:

![](/images/48/atb2.jpg)

Мы можем добавить разделитель используя следующую строку:

    // Второй аргумент это не обязательное имя.
    TwAddSeparator(bar, "", NULL);

Теперь мы имеем:

![](/images/48/atb3.jpg)

Что же, давайте попробуем привязать нашу камеру таким образом, что бы всегда
видить её положение и направление. К этому моменту вы должно быть уже печатали
параметры камеры что бы использовать их после, но, согласитесь, отображать их в
интерфейсе куда удобнее. Для повторного использования кода я добавил функцию
*AddToATB()* в класс камеры. Она состоит из трёх вызовов к ATB. Первый просто
использует *TwAddButton()* для добавления строки к интерфейсу. TwAddButton()
очень мощная функция и мы узнаем другие её применения чуть позже. Затем мы
вызываем *TwAddVarRW()*, которая добавляет изменяемую переменную и *TwAddVarRO()*
для добавления переменных только для чтения. Изменяемой переменной в нашем
случае будет позиция камеры, её легко изменить в интерфейсе и это отразится
в приложении. Удивительно, но ATB не имеет внутреннего типа для массива их
трёх чисел, поэтому я добавил собственный для использования фреймворком:

> ogldev_atb.cpp:38

    TwStructMember Vector3fMembers[] = {
        { "x", TW_TYPE_FLOAT, offsetof(Vector3f, x), "" },
        { "y", TW_TYPE_FLOAT, offsetof(Vector3f, y), "" },
        { "z", TW_TYPE_FLOAT, offsetof(Vector3f, z), "" }
    };

    TW_TYPE_OGLDEV_VECTOR3F = TwDefineStruct("Vector3f", Vector3fMembers, 3, sizeof(Vector3f), NULL, NULL);

Теперь мы можем использовать *TW_TYPE_OGLDEV_VECTOR3F* там, где требуется добавить
виджет с вектором из трёх чисел. А вот и полная версия функции AddToATB():

    void Camera::AddToATB(TwBar* bar)
    {
          TwAddButton(bar, "Camera", NULL, NULL, "");
          TwAddVarRW(bar, "Position", TW_TYPE_OGLDEV_VECTOR3F, (void*)&m_pos, NULL);
          TwAddVarRO(bar, "Direction", TW_TYPE_DIR3F, &m_target, " axisz=-z ");
    }

Мы используем тип *TW_TYPE_DIR3F* для отображения массива из трёх чисел в виде стрелки.
Обратим внимание на последний параметр *axisz=-z* функции TwAddVarRO(). Многие функции
ATB принимают строку с настройками в качестве последнего аргумента. Это позволяет
изменять внутреннее поведение функции. axisz используется для перехода от правосторонней
системы координат (используется в ATB) к левосторонней (OGLDEV фреймворк). Есть ещё
множество дополнительных опций, и я просто не могу рассказать о них всех.
Вы можете найти их по [ссылке](http://anttweakbar.sourceforge.net/doc/tools:anttweakbar:varparamsyntax).

Вот как выглядит интерфейс с добавленной камерой:

![](/images/48/atb4.jpg)

Наверняка вы проводите немало времени играясь с положением мешей в пространстве. Давайте
добавим что-нибудь в интерфейс что бы упростить эту задачу. Идея состоит в использовании
кватерниона, который может быть использован для вращения меша. Для начала мы добавим переменную
с кватернионом (определение структуры в ogldev_math_3d.h):

    Quaternion g_Rotation = Quaternion(0.0f, 0.0f, 0.0f, 0.0f);

Затем мы привязываем переменную кватерниона к интерфейсу используя тип *TW_TYPE_QUAT4F*:

    TwAddVarRW(bar, "ObjRotation", TW_TYPE_QUAT4F, &g_Rotation, " axisz=-z ");

И снова мы должны перейти от правоориентированной системы к левоориентированной. Кроме того,
конвертируем кватернион в градусы:

    m_mesh[m_currentMesh].GetOrientation().m_rotation = g_Rotation.ToDegrees();

Теперь вектор вращения может быть использован для ориентации меша и генерации матрицы WVP:

    m_pipeline.Orient(m_mesh[m_currentMesh].GetOrientation());

Теперь интерфейс выглядит следующим образом:

![](/images/48/atb5.jpg)

Теперь давайте добавим флажок, который будет включать и отключать автоматическое вращение
меша вокруг оси Y. Для начала добавим кнопку:

    TwAddButton(bar, "AutoRotate", AutoRotateCB, NULL, " label='Auto rotate' ");

Третий параметр это функция, которая вызывается при щелчке на флажок, а четвёртый это
параметр передаваемый в каллбэк. Поскольку он мне не нужен, я использую NULL.

    bool gAutoRotate = false;

    void TW_CALL AutoRotateCB(void *p)
    {
        gAutoRotate = !gAutoRotate;
    }

Теперь можно использовать gAutoRotate для автоматического и ручного вращения.

Теперь интерфейс выглядит так:

![](/images/48/atb6.jpg)

Другой полезным виджетом будет управление скоростью вращения (когда автоматическое вращение включено).
Этот виджет предоставляет несколько способов задавать его значение:

    TwAddVarRW(bar, "Rot Speed", TW_TYPE_FLOAT, &m_rotationSpeed,
               " min=0 max=5 step=0.1 keyIncr=s keyDecr=S help='Rotation speed (turns/second)' ");

Первые четыре параметра очевидны. Это указатель на интерфейс, строка для показа, тип параметра и адрес
переменной, куда будет записываться значение. Самое интересное в конце, в строке с параметрами. Для
начала, мы ограничиваем значение в отрезке от 0 до 5, а шаг увеличения / уменьшения устанавливаем в 0.1.
Мы назначаем горячие клавиши *s* и *d* для увеличения и уменьшения значения соответственно. Если провести
курсором над виджетом, то вы увидите горячие клавиши внизу интерфейса. Можно ввести значение вручную,
использовать горячие клавиши, нажимать на символы '+' или '-' справа или использовать рычаг для
изменения значения (показывается при щелчке на кружек). Вот как выглядит интерфейс с этим виджетом:

![](/images/48/atb7.jpg)

In all of the tutorials there is usually at least one light source so it makes sense to add some code that will allow us to
easily hook it up to the tweak bar so we can play with it parameters. So I went ahead and added the following methods to the
various light source classes:

    void BaseLight::AddToATB(TwBar *bar)
    {
          std::string s = Name + ".Color";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_COLOR3F, &Color, NULL);
          s = Name + ".Ambient Intensity";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_FLOAT, &AmbientIntensity, "min=0.0 max=1.0 step=0.005");
          s = Name + ".Diffuse Intensity";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_FLOAT, &DiffuseIntensity, "min=0.0 max=1.0 step=0.005");
    }


    void DirectionalLight::AddToATB(TwBar *bar)
    {
          BaseLight::AddToATB(bar);
          std::string s = Name + ".Direction";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_DIR3F, &Direction, "axisz=-z");
    }


    void PointLight::AddToATB(TwBar *bar)
    {
          BaseLight::AddToATB(bar);
          std::string s = Name + ".Position";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_OGLDEV_VECTOR3F, &Position, "axisz=-z");
          s = Name + ".Attenuation";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_OGLDEV_ATTENUATION, &Attenuation, "");
    }


    void SpotLight::AddToATB(TwBar *bar)
    {
          PointLight::AddToATB(bar);
          std::string s = Name + ".Direction";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_DIR3F, &Direction, "axisz=-z");
          s = Name + ".Cutoff";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_FLOAT, &Cutoff, "");
    }

Note that 'Name' is a new string memeber of the BaseLight class that must be set before AddToATB() function
is called on the light object. It represents the string that will be displayed in the tweak bar for that light.
If you plan on adding multiple lights you must make sure to pick up unique names for them. AddToATB() is a virtual
function so the correct instance according to the concrete class is always called. Here's the bar
with a directional light source:

![](/images/48/atb8.jpg)

The last thing that I want to demonstrate is the ability to get and set various parameters that control the behaviour
of the tweak bar. Here's an example of setting the refresh rate of the bar to one tenth of a second:

    float refresh = 0.1f;
    <b>TwSetParam</b>(bar, NULL, "refresh", TW_PARAM_FLOAT, 1, &refresh);

Since moving the mouse to the tweak bar means that the camera also moves I made the key 'a' automatically move the
mouse to the center of the tweak bar without touching the camera. I had to read the location and size of the tweak bar
in order to accomplish that so I used TwGetParam() in order to do that:

    virtual void KeyboardCB(OGLDEV_KEY OgldevKey)
    {
        if (!m_atb.KeyboardCB(OgldevKey)) {
            switch (OgldevKey) {
                case OGLDEV_KEY_A:
                {
                    int Pos[2], Size[2];
                    <b>TwGetParam</b>(bar, NULL, "position", TW_PARAM_INT32, 2, Pos);
                    <b>TwGetParam</b>(bar, NULL, "size", TW_PARAM_INT32, 2, Size);
                    OgldevBackendSetMousePos(Pos[0] + Size[0]/2, Pos[1] + Size[1]/2);
                    break;
                }
