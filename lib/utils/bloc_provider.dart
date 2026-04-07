// import 'package:comedor_app/bloc/auth/bloc.dart';
// import 'package:comedor_app/bloc/cart/cart_bloc.dart';
// import 'package:comedor_app/bloc/cart/cart_event.dart';
// import 'package:comedor_app/bloc/theme/theme_bloc.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:comedor_app/services/auth_service.dart';

// List<BlocProvider> blocsServices() {
//   return [
//     // 🔐 BLoC de Auth inyectado correctamente
//     BlocProvider<LoginBloc>(
//       create: (context) => LoginBloc(context.read<AuthService>()),
//     ),

//     BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),

//     BlocProvider<CartBloc>(
//       create: (_) => CartBloc()..add(OnLoadCart()),
//     ),

//     // 🛒 NUESTRO NUEVO CART BLOC
//     BlocProvider<CartBloc>(
//       // La magia "..add(OnLoadCart())" hace que el carrito
//       // busque en el SecureStorage apenas se abre la app
//       create: (context) => CartBloc()..add(OnLoadCart()),
//     ),
//   ];
// }
