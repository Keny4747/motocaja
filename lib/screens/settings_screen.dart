import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<String?> _ask(BuildContext context, String title, String current) async {
    final c = TextEditingController(text: current);
    return showDialog<String>(context: context, builder: (_) => AlertDialog(title: Text(title), content: TextField(controller: c, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Guardar'))]));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 18), children: [
      const Center(child: Text('Configuración', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy))),
      const SizedBox(height: 16),
      const _Header('Mi perfil'),
      Row(children: [Expanded(child: _SettingTile(icon: Icons.person, title: state.name, onTap: () async { final v = await _ask(context,'Nombre',state.name); if (v?.isNotEmpty == true && context.mounted) context.read<AppState>().updateProfile(newName:v); })), const SizedBox(width: 10), Expanded(child: _SettingTile(icon: Icons.two_wheeler, title: state.vehicle, onTap: () async { final v = await _ask(context,'Vehículo',state.vehicle); if (v?.isNotEmpty == true && context.mounted) context.read<AppState>().updateProfile(newVehicle:v); }))]),
      const SizedBox(height: 16),
      const _Header('Preferencias'),
      const _SettingTile(icon: Icons.percent, title: 'Tarifas frecuentes', subtitle: 'S/ 5, S/ 7, S/ 8, S/ 10'),
      _SettingTile(icon: Icons.credit_card, title: 'Método de pago predeterminado', subtitle: state.defaultPayment, onTap: () => _paymentSheet(context,state)),
      const SizedBox(height: 16),
      const _Header('Recordatorios'),
      _SwitchTile(icon: Icons.notifications, title: 'Recordarme registrar ingresos', value: state.remindIncome, onChanged: state.setReminderIncome),
      _SwitchTile(icon: Icons.notifications, title: 'Recordarme cerrar mi día', value: state.remindClose, onChanged: state.setReminderClose),
      const _SettingTile(icon: Icons.schedule, title: 'Hora de cierre', subtitle: '9:00 PM'),
      const SizedBox(height: 16),
      const _Header('Datos'),
      const _SettingTile(icon: Icons.download_outlined, title: 'Exportar información'),
      const SizedBox(height: 16),
      const _Header('Acerca de'),
      const _SettingTile(icon: Icons.info_outline, title: 'Acerca de MotoCaja', subtitle: 'Versión 1.0.0'),
    ]));
  }

  void _paymentSheet(BuildContext context, AppState state) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: ['Efectivo','Yape','Plin','Transferencia'].map((p) => RadioListTile<String>(value:p, groupValue:state.defaultPayment, title:Text(p), onChanged:(v){ if(v!=null){ state.updateProfile(newDefaultPayment:v); Navigator.pop(context); }})).toList())));
  }
}

class _Header extends StatelessWidget { final String text; const _Header(this.text); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Text(text,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13))); }
class _SettingTile extends StatelessWidget { final IconData icon; final String title; final String? subtitle; final VoidCallback? onTap; const _SettingTile({required this.icon,required this.title,this.subtitle,this.onTap}); @override Widget build(BuildContext context)=>InkWell(onTap:onTap,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:AppColors.border),borderRadius:BorderRadius.circular(9)),child:Row(children:[Icon(icon,color:AppColors.navy,size:21),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),if(subtitle!=null)Text(subtitle!,style:const TextStyle(fontSize:10,color:AppColors.muted))])),const Icon(Icons.chevron_right,color:AppColors.muted,size:19)]))); }
class _SwitchTile extends StatelessWidget { final IconData icon; final String title; final bool value; final ValueChanged<bool> onChanged; const _SwitchTile({required this.icon,required this.title,required this.value,required this.onChanged}); @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.only(left:12),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:AppColors.border),borderRadius:BorderRadius.circular(9)),child:Row(children:[Icon(icon,color:AppColors.navy,size:20),const SizedBox(width:11),Expanded(child:Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),Switch(value:value,onChanged:onChanged,activeColor:AppColors.green)])); }
